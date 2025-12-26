import discord
from discord import app_commands
from uart import send_to_fpga, FPGAConnectionError
import secrets

TOKEN = "SECRET" #nanti dimasukin pas mau run

def parse_kat_block(text: str) -> dict:
    data = {}

    for line in text.splitlines():
        line = line.strip()
        if "=" in line:
            k, v = line.split("=", 1)
            data[k.strip()] = v.strip()

    return data

class CryptoBot(discord.Client):
    def __init__(self):
        intents = discord.Intents.default()
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()

bot = CryptoBot()

@bot.tree.command(name="encrypt")
async def encrypt(
    interaction: discord.Interaction,
    plaintext: str,
    ad: str = ""
):
    key = secrets.token_hex(16)
    nonce = secrets.token_hex(16)

    payload = {
        "mode": "encrypt",
        "key": key,
        "nonce": nonce,
        "associated_data": ad.encode().hex(),
        "plaintext": plaintext.encode().hex()
    }

    try:
        result = send_to_fpga(payload)

    except FPGAConnectionError:
        if not interaction.response.is_done():
            await interaction.response.send_message(
                "❌ **FPGA tidak terhubung**\n"
                "Pastikan FPGA dan koneksi UART aktif sebelum enkripsi.",
                ephemeral=True
            )
        return

    await interaction.response.send_message(
        f"🔐 **Encryption Result**\n"
        f"CT = `{result['ciphertext']}{result['tag']}`"
    )

@bot.tree.command(name="decrypt")
async def decrypt(
    interaction: discord.Interaction,
    ciphertext: str,
    tag: str,
    nonce: str,
    key: str,
    ad: str = ""
):
    payload = {
        "mode": "decrypt",
        "key": key,
        "nonce": nonce,
        "associated_data": ad.encode().hex(),
        "ciphertext": ciphertext,
        "tag": tag
    }

    try:
        result = send_to_fpga(payload)

    except FPGAConnectionError:
        if not interaction.response.is_done():
            await interaction.response.send_message(
                "❌ FPGA tidak terhubung.\nDekripsi tidak dapat dilakukan.",
                ephemeral=True
            )
        return

    if result["status"] == "success":
        plaintext = bytes.fromhex(result["plaintext"]).decode()
        await interaction.response.send_message(
            f"🔓 **Decryption Result**\nPT = `{plaintext}`"
        )
    else:
        await interaction.response.send_message("❌ Authentication failed")

bot.run(TOKEN)
import discord
from discord import app_commands
from uart import send_to_fpga
import secrets

TOKEN = "MTQ1MTQzNzYwNjA3MDkxMTEwOA.GTySLg.5o5OwLiyx94DL6odGM4ZoGfwrTO70BXIMJ5aTc"

class CryptoBot(discord.Client):
    def __init__(self):
        intents = discord.Intents.default()
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()

bot = CryptoBot()

@bot.tree.command(name="encrypt", description="Encrypt message using ASCON-AEAD128")
async def encrypt(interaction: discord.Interaction, message: str):
    key = secrets.token_hex(16)
    nonce = secrets.token_hex(16)

    payload = {
        "mode": "encrypt",
        "key": key,
        "nonce": nonce,
        "associated_data": "",
        "plaintext": message.encode().hex()
    }

    result = send_to_fpga(payload)

    await interaction.response.send_message(
        f"🔐 **Encryption Result**\n"
        f"Ciphertext: `{result['ciphertext']}`\n"
        f"Tag: `{result['tag']}`\n"
        f"Nonce: `{nonce}`"
    )

@bot.tree.command(name="decrypt", description="Decrypt ciphertext using ASCON-AEAD128")
async def decrypt(
    interaction: discord.Interaction,
    ciphertext: str,
    tag: str,
    nonce: str,
    key: str
):
    payload = {
        "mode": "decrypt",
        "key": key,
        "nonce": nonce,
        "associated_data": "",
        "ciphertext": ciphertext,
        "tag": tag
    }

    result = send_to_fpga(payload)

    if result["status"] == "success":
        plaintext = bytes.fromhex(result["plaintext"]).decode()
        await interaction.response.send_message(f"🔓 Plaintext: `{plaintext}`")
    else:
        await interaction.response.send_message("❌ Authentication failed")

bot.run(TOKEN)
import discord
from discord import app_commands
from uart import send_to_fpga
import secrets

TOKEN = "MTQ1MTQzNzYwNjA3MDkxMTEwOA.GzPWd8.59TVQAenI3hwZlag1dwX_Px8xf95jLMveKolRo" #nanti dimasukin pas mau run

class CryptoBot(discord.Client):
    def __init__(self):
        intents = discord.Intents.default()
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()

bot = CryptoBot()

@bot.tree.command(name="encrypt")
async def encrypt(interaction: discord.Interaction, message: str):
    key = secrets.token_hex(16).upper()
    nonce = secrets.token_hex(16).upper()

    payload = {
        "mode": "encrypt",
        "key": key,
        "nonce": nonce,
        "associated_data": "00",
        "plaintext": message.encode().hex().upper()
    }

    result = send_to_fpga(payload)

    if result.get("status") == "error":
        await interaction.response.send_message(
            f"❌ **Encryption failed**\n{result['message']}"
        )
        return

    ct_tag = result["ciphertext"].upper() + result["tag"].upper()
    kat_line = f"{key} {nonce} 00 {ct_tag}\n"

    filename = "kat_vectors.txt"
    with open(filename, "w") as f:
        f.write(kat_line)

    await interaction.response.send_message(
        content="🔐 Encryption successful",
        file=discord.File(filename)
    )


@bot.tree.command(name="decrypt")
async def decrypt(interaction: discord.Interaction, ciphertext: str, tag: str, nonce: str, key: str):
    payload = {
        "mode": "decrypt",
        "key": key,
        "nonce": nonce,
        "associated_data": "00",
        "ciphertext": ciphertext,
        "tag": tag
    }

    result = send_to_fpga(payload)

    if result.get("status") == "error":
        await interaction.response.send_message(
            f"❌ **Decryption failed**\n{result['message']}"
        )
        return

    if result.get("auth") == "fail":
        await interaction.response.send_message("❌ Authentication failed")
        return

    plaintext = bytes.fromhex(result["plaintext"]).decode()
    await interaction.response.send_message(f"🔓 Plaintext: `{plaintext}`")


bot.run(TOKEN)
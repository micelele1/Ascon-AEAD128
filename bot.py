import discord
from discord import app_commands
import secrets

from uart import send_to_fpga, FPGAConnectionError, FPGAProtocolError

TOKEN = "SECRET"

MODE_ENCRYPT = 0x01
MODE_DECRYPT = 0x02


class CryptoBot(discord.Client):
    def __init__(self):
        intents = discord.Intents.default()
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()


bot = CryptoBot()


def build_frame(mode: int, key: bytes, nonce: bytes, data: bytes) -> bytes:
    if len(key) != 16 or len(nonce) != 16 or len(data) != 16:
        raise ValueError("Key, nonce, and data must be 16 bytes")

    frame = bytearray(64)
    frame[0] = mode
    frame[1:17] = key
    frame[17:33] = nonce
    frame[33:49] = data
    # byte 49–63 otomatis 0x00
    return bytes(frame)


@bot.tree.command(name="encrypt", description="Encrypt plaintext using ASCON-AEAD128 (FPGA)")
async def encrypt(
    interaction: discord.Interaction,
    plaintext: str
):
    key = secrets.token_bytes(16)
    nonce = secrets.token_bytes(16)

    pt_bytes = plaintext.encode()
    if len(pt_bytes) > 16:
        await interaction.response.send_message(
            "❌ Plaintext maksimal 16 byte",
            ephemeral=True
        )
        return

    pt_bytes = pt_bytes.ljust(16, b"\x00")

    frame = build_frame(
        MODE_ENCRYPT,
        key,
        nonce,
        pt_bytes
    )

    try:
        response = send_to_fpga(frame)
    except FPGAConnectionError:
        await interaction.response.send_message(
            "❌ FPGA tidak terhubung",
            ephemeral=True
        )
        return
    except FPGAProtocolError as e:
        await interaction.response.send_message(
            f"❌ Protokol UART error: {e}",
            ephemeral=True
        )
        return

    ciphertext = response[33:49].hex()

    await interaction.response.send_message(
        f"🔐 **Encryption Result**\n"
        f"Ciphertext: `{ciphertext}`\n"
        f"Key: `{key.hex()}`\n"
        f"Nonce: `{nonce.hex()}`"
    )


@bot.tree.command(name="decrypt", description="Decrypt ciphertext using ASCON-AEAD128 (FPGA)")
async def decrypt(
    interaction: discord.Interaction,
    ciphertext: str,
    key: str,
    nonce: str
):
    try:
        ct_bytes = bytes.fromhex(ciphertext)
        key_bytes = bytes.fromhex(key)
        nonce_bytes = bytes.fromhex(nonce)
    except ValueError:
        await interaction.response.send_message(
            "❌ Format hex tidak valid",
            ephemeral=True
        )
        return

    if len(ct_bytes) != 16 or len(key_bytes) != 16 or len(nonce_bytes) != 16:
        await interaction.response.send_message(
            "❌ Ciphertext, key, dan nonce harus 16 byte",
            ephemeral=True
        )
        return

    frame = build_frame(
        MODE_DECRYPT,
        key_bytes,
        nonce_bytes,
        ct_bytes
    )

    try:
        response = send_to_fpga(frame)
    except FPGAConnectionError:
        await interaction.response.send_message(
            "❌ FPGA tidak terhubung",
            ephemeral=True
        )
        return
    except FPGAProtocolError as e:
        await interaction.response.send_message(
            f"❌ Protokol UART error: {e}",
            ephemeral=True
        )
        return

    plaintext = response[33:49].rstrip(b"\x00").decode(errors="ignore")

    await interaction.response.send_message(
        f"🔓 **Plaintext**: `{plaintext}`"
    )


bot.run(TOKEN)

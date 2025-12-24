const { Client, GatewayIntentBits } = require('discord.js');
const crypto = require('crypto');
const sendToFPGA = require('./uart');

const TOKEN = "MTQ1MTQzNzYwNjA3MDkxMTEwOA.GTySLg.5o5OwLiyx94DL6odGM4ZoGfwrTO70BXIMJ5aTc";

const client = new Client({
  intents: [GatewayIntentBits.Guilds]
});

client.once('ready', () => {
  console.log(`Logged in as ${client.user.tag}`);
});

client.on('interactionCreate', async interaction => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'encrypt') {
    const message = interaction.options.getString('message');
    const key = crypto.randomBytes(16).toString('hex');
    const nonce = crypto.randomBytes(16).toString('hex');

    const payload = {
      mode: "encrypt",
      key: key,
      nonce: nonce,
      associated_data: "",
      plaintext: Buffer.from(message).toString('hex')
    };

    const result = await sendToFPGA(payload);

    await interaction.reply(
      `🔐 Ciphertext: \`${result.ciphertext}\`\n` +
      `Tag: \`${result.tag}\`\nNonce: \`${nonce}\``
    );
  }

  if (interaction.commandName === 'decrypt') {
    const payload = {
      mode: "decrypt",
      key: interaction.options.getString('key'),
      nonce: interaction.options.getString('nonce'),
      associated_data: "",
      ciphertext: interaction.options.getString('ciphertext'),
      tag: interaction.options.getString('tag')
    };

    const result = await sendToFPGA(payload);

    if (result.status === "success") {
      const plaintext = Buffer.from(result.plaintext, 'hex').toString();
      await interaction.reply(`🔓 Plaintext: \`${plaintext}\``);
    } else {
      await interaction.reply("❌ Authentication failed");
    }
  }
});

client.login(TOKEN);

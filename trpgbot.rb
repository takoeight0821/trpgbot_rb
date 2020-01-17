STDOUT.sync = true

require 'discordrb'

$LOAD_PATH.unshift File.join(__dir__, 'BCDice', 'src')
require_relative './BCDice/src/bcdiceCore'
require_relative './BCDice/src/diceBot/DiceBot'
require_relative './BCDice/src/diceBot/DiceBotLoader'

class BCDice
  DICEBOTS = (DiceBotLoader.collectDiceBots + [DiceBot.new]).map do |dice_bot|
    [dice_bot.gameType, dice_bot]
  end.sort.to_h.freeze

  SYSTEMS = DICEBOTS.keys.sort.freeze

  NAMES = DICEBOTS.map { |game_type, dice_bot| { system: game_type, name: dice_bot.gameName } }
                  .freeze
end

module TRPGBot
  class UnsupportedDicebot < StandardError; end

  class CommandError < StandardError; end

  class ToStringClient
    attr_accessor :output
    def quit; end

    def sendMessage(_to, message)
      @output ||= ""
      @output << message
      @output << "\r\n"
    end
  
    def sendMessageToOnlySender(_nick_e, message)
      @output ||= ""
      @output << message
      @output << "\r\n"
    end
  
    def sendMessageToChannels(message)
      @output ||= ""
      @output << message
      @output << "\r\n"
    end

    def getMessage
      o = @output
      @output = ""
      o
    end
  end

  # TRPG bot on Discord
  class Bot < Discordrb::Commands::CommandBot
    # @return [Hash] bot config for each channels
    attr_accessor :env_table
    # @return [BCDice]
    attr_reader :bcdice

    def initialize(*args)
      super(*args)
      @bcdice = BCDiceMaker.new.newBcDice
      @toStr = ToStringClient.new
      @bcdice.setIrcClient(@toStr)
      @env_table = {}
    end

    # @param id [Integer] channel id
    # @return [Hash] bot config for the channel
    def env(id)
      @env_table ||= {}
      @env_table[id] ||= { system: 'DiceBot' }
      @env_table[id]
    end

    # @param id [Integer] channel id
    # @param key [Symbol] key of config
    # @param val [Object] new value
    def set_env(id, key, val)
      @env_table ||= {}
      @env_table[id] ||= { system: 'DiceBot' }
      @env_table[id][key] = val
    end

    def update_bcdice(system, command)
      dicebot = BCDice::DICEBOTS[system]

      raise UnsupportedDicebot if dicebot.nil?

      raise CommandError if command.nil? || command.empty?

      @bcdice.setDiceBot(dicebot)
      @bcdice.setMessage(command)
      @bcdice.setDir('bcdice/extratables', system)
      @bcdice.setCollectRandResult(true)
      @bcdice
    end

    def help(id)
      system = env(id)[:system]
      dicebot = BCDice::DICEBOTS[system]
      output = <<"EOS"
- 加算ロール　　　　　　（xDn）（n面体ダイスをx個）
- バラバラロール　　　　（xBn）
- 個数振り足しロール   （xRn[振り足し値]）
- 上方無限ロール      （xUn[境界値]）
- シークレットロール   （Sダイスコマンド）（DMで結果が届く）
- 四則演算（端数切捨て）（C(式)）
EOS
      output << dicebot.getHelpMessage
      output
    end

    def diceroll(id, command)
      system = env(id)[:system]
      bcdice = update_bcdice(system, command)
      result, secret = bcdice.dice_command

      puts "DICEROLL: #{[system, command]} #{[result, secret]}"

      raise CommandError if result.nil? || result == '1'

      [result, secret]
    end
  end
end

bot = TRPGBot::Bot.new(
  token: ENV['BOT_TOKEN'],
  prefix: '$',
  ignore_bots: true
)

bot.command [:roll, :r, :dice] do |event, dice, system = nil|
  save = bot.env_table

  begin
    bot.set_env(event.channel.id, :system, system) unless system.nil?

    result, secret = bot.diceroll(event.channel.id, dice)
    msg = BCDice::DICEBOTS[bot.env(event.channel.id)[:system]].gameName + result

    bot.env_table = save
    if secret
      event.user.pm msg
    else
      event << msg
    end
  rescue TRPGBot::CommandError => e
    event << e.to_s
  end

  nil
end

bot.command :set_system do |event, system|
  bot.set_env(event.channel.id, :system, system)
  "set system #{system} (#{BCDice::DICEBOTS[system].gameName})"
end

bot.command :help do |event|
  bot.help(event.channel.id)
end

bot.command :show_env do |event|
  bot.env(event.channel.id).to_s
end

bot.run

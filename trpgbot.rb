STDOUT.sync = true

# Discord API
require 'discordrb'

# BCDice
require 'bcdice'

module TRPGBot
  # TRPG bot definition
  class Bot < Discordrb::Commands::CommandBot
    include BCDice

    def initialize(*args)
      super(*args)
      # TODO: serverごとに異なるダイスボットを利用できるようにする
      @game_system = GameSystem::DiceBot
    end

    def update_nickname(event)
      if self.member(event.channel.server, self.profile.id).nickname != "TRPGBot (#{@game_system::NAME})"
        self.member(event.channel.server, self.profile.id).nickname = "TRPGBot (#{@game_system::NAME})"
      end
      nil
    end

    # ゲームシステムを切り替える
    def load_game_system(event, game_system)
      klass = BCDice.dynamic_load(game_system)
      if klass
        @game_system = klass
        event << "#{@game_system::NAME} loaded"
      else
        event << "#{game_system} not found"
      end
    end

    def show_help(event)
      help_message = <<~HELP
        TrpgBot commands:
          use GAME_SYSTEM   # 使うゲームシステムを指定する
          set GAME_SYSTEM   # 同上
          help              # このメッセージを表示する
      HELP
      event << help_message
      event << <<~HELP
        ・ 加算ロール　　　　　　（xDn）（n面体ダイスをx個）
        ・ バラバラロール　　　　（xBn）
        ・ 個数振り足しロール   （xRn[振り足し値]）
        ・ 上方無限ロール      （xUn[境界値]）
        ・ シークレットロール   （Sダイスコマンド, 現在未実装）
        ・ 四則演算（端数切捨て）（C(式)）
      HELP
      event << @game_system::HELP_MESSAGE
    end

    def parse_command(message)
      /^#{@game_system.command_pattern}$/.match message
      $& #return matched string
    end

    def run_command(command)
      gs = @game_system.new(command)
      gs.eval()
    rescue StandardError => e
      puts e
    end
  end
end

bot = TRPGBot::Bot.new(
  token: ENV['BOT_TOKEN'],
  prefix: '$',
  ignore_bots: true
)

bot.command [:use, :set] do |event, game_name|
  bot.load_game_system event, game_name
  bot.update_nickname event
end

bot.command :help do |event|
  bot.show_help event
end

bot.message do |event|
  result = bot.run_command event.content
  unless result.nil?
    bot.update_nickname event
    event << result.text
  end
end

bot.run
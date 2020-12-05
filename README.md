# Trpgbot

BCDice (https://bcdice.org/) を利用したDiscord用ダイスボット
Discord Botを自分で作ってトークンを渡すと動きます。
まだあまりちゃんと作ってないので、動作保証はありません。

## Installation

githubからダウンロード

```
$ git clone https://github.com/takoeight0821/trpgbot_rb
```

Bundlerで依存ライブラリをインストール

```
$ bundle install
```

## Usage

ダイスロールはBCDiceのコマンドに対応。

`$use <システム名>`でシステム変更。

Botの起動は以下のコマンド

    $ BOT_TOKEN=<Discord botのトークン> bundle exec ruby trpbbot.rb

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/trpgbot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Trpgbot project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/trpgbot/blob/master/CODE_OF_CONDUCT.md).
=======

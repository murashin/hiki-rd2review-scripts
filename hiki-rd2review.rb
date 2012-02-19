#!/usr/local/bin/ruby19
# -*- coding: utf-8 -*-
#
# Copyright 2012 Shin-ya MURAKAMI <murashin _at_ gfd-dennou.org>
#
#

=begin

= rd記法からreview記法に変換

正規表現でちまちま置換。

王道はrdtoolに変換機能を実装することだろうが、
ちょっとしたものならばこれで変換可能なはずである。

* 入力ファイルは、JISを想定。
* hikiのrd形式を入力することを想定。

== バグ

以下をサポートしていない。

* 連番付きリスト
* テーブルの変換

他にもまちがいなくもっとある。

== review記法とrd記法の違いのメモ

=== 箇条書

re:
 * 1
 ** 1-1
 *** 1-1-1
 ** 1-2
 * 2

rd:
 * 1
   * 1-1
     * 1-1-1
   * 1-2
 * 2

=== 強調(太字)

* rd:
 ((* foo *))
* re:
 @<em>{ foo }

=== リンク

* rd:
 ((<titlehoge|URL:http://www.example.com>))
* re:
  @<href>{http://github.com/, GitHub}
  @<href>{http://www.google.com/}
  @<href>{#point1, ドキュメント内ポイント}
  @<href>{chap1.html#point1, ドキュメント内ポイント}
  //label[point1]

=== リスト

* re:
 //emlist[識別子][キャプション]{
 foo
 //}

=end

exit if ARGV.empty?

# specify dstdir
if not ARGV[1].nil?
  dstdir = ARGV[1]
else
  dstdir = "."
end

CHAPS = dstdir + '/CHAPS.sample'

require 'nkf'

ofn_path = "#{ARGV[0]}" # ARGV[0]はConstなので、別のオブジェクトを生成
ofn = ofn_path.split('/').last
ofn_utf8 = NKF::nkf( '-J -w -mQ', ofn.gsub( /%([0-9A-F][0-9A-F])/ , '=\1') )
ofn_utf8.gsub!(/\+/, '_') # white spaceはアンダースコアで置き換え。(ReVIEW側の制約?)
ofn_utf8.gsub!(/\//, '-') # /はハイフンで置き換え。(Unixファイルシステムの制約)
ofn_utf8 = "#{ofn_utf8}.re"
ofn_utf8_path = "#{dstdir}/#{ofn_utf8}"

# CHAPSファイルのサンプル準備
open( CHAPS, "a+", {:external_encoding=>"utf-8",
        :internal_encoding=>"utf-8"} ){|io|
  io.write "#{ofn_utf8}\n"
}

outf = open( ofn_utf8_path, "w+", {:external_encoding=>"utf-8",
               :internal_encoding=>"utf-8"}  )
in_pre = false  # inside pre-formatted text
in_rt = false   # inside rt table
in_list = false # inside list

open( ofn_path, "r", {:external_encoding=>"euc-jp",
                 :internal_encoding=>"utf-8"} ) do |io|
  lines = io.readlines
  lines.each do |l|
    # pre変換
    if in_pre
      # 前の行がpreの内側の場合。
      if /^$/ =~ l
        # pre 終了
        outf.write "//}\n"
        in_pre = false 
        in_list = false
        in_rt = false
      elsif /^\s/ =~ l
        outf.write l
        next
      else
        outf.write "//}\n"
        in_pre = false
        in_list = false
        in_rt = false
      end
    end
    # RT変換
    l.gsub!( /^\ #RT/, '' )
    # 色々変換
    l.gsub!( /^\#.*/, '#@#' )                 # コメント
    l.gsub!( /\(\(\*(.*)\*\)\)/, '@<em>{\1}') # 強調
    l.gsub!( /\{\{toc\}\}/, '#@warn({{toc}})') # tocの変換は未実装なのでコメント
    l.gsub!( /\{\{toc_here\}\}/, '#@warn({{toc_here}})') # tocの変換は未実装なのでコメント
    # URL 変換
    if /\(\(<URL:(.+?)>\)\)/ =~ l
      l.gsub!( /\(\(<URL:(.+?)>\)\)/, '@<href>{\1}' )
    elsif /\(\(<(.+?)\|URL:(.+?)>\)\)/ =~ l
      l.gsub!( /\(\(<(.+?)\|URL:(.+?)>\)\)/, '@<href>{\2, \1}' )
      l.gsub!( /(@<href>{.+), "(.+)"}/, '\1, \2}' ) # タイトルが""で囲まれてたら除去
    elsif /\(\(<(.+?)\|URL:(.+?)>\)\)/ =~ l
      l.gsub!( /\(\(<(.+?)\|(.+?)>\)\)/, '@<href>{\2, \1}' )
      l.gsub!( /(@<href>{.+), "(.+)"}/, '\1, \2}' ) # タイトルが""で囲まれてたら除去
    elsif /\(\(<(.+?)>\)\)/ =~ l
      l.gsub!( /\(\(<(.+?)>\)\)/, '@<href>{\1}' )
    end
    # 箇条書きを変換
    if /^\s*\*/ =~ l
      l.gsub!( /^\*/, "*" )
      l.gsub!( /^\s\s\*/, "**" )
      l.gsub!( /^\s\s\s\s\*/, "***" )
      l.gsub!( /^\s\s\s\s\s\s\*/, "****" )
      l.gsub!( /^\s\s\s\s\s\s\s\s\*/, "*****" )
      in_list = true
    end
    # 前の行が pre の内側でなく、改行のみでもなく、リストでもなく、先頭空白で始まった場合
    if /^$/ =~ l
      in_pre = false
      in_list = false
      in_rt = false
    else
      if /^\s/ =~ l and not /^\s\*/ =~ l and not in_list
        # pre開始
        # BUG: " #RT" で始まる場合は 
        #      //table[識別子]{キャプション} ... //} にしないといけない
        outf.write "//emlist{\n"
        in_pre = true
      elsif in_list
        outf.write " " # リスト内インデントのために空白文字を一文字追加
      else
        #
      end
    end
    outf.write l
  end
end

# in_pre/in_rtがtrueのままEOFを向かえたら、閉じる
if in_pre or in_rt
  outf.write "//}\n"
end

outf.close

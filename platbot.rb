#db = PG postgresql
#channel_idをキーに小隊管理

#execute sql below first
#db.exec('create table plat (channel_id integer primary key, server_id integer, description text, cap integer, leader integer, member_id_list text, queue_id_list text, created_at integer);')
#db.exec('create table name (id integer, name text);')


require './data'
require 'discordrb'
require 'open-uri'
require 'time'
require 'pg'

A7ID = 238575590456688641 #my discord account id
#change values to your channel id
if ARGV[0] == "-l"
  pl1ch = 417527891866288129
  pl2ch = 417528974025949195
  pllch = 425619258710556673
else
  pl1ch = 473659418760970260
  pl2ch = 473659420799139850
  pllch = 473659237739003914
end

bot = Discordrb::Commands::CommandBot.new(
  client_id: BOT_ID,
  token: TOKEN,
  prefix: DEFAULT_PREFIX #['!!', '!', ';;', ';', '/']
)
plchannels = [pl1ch, pl2ch]
pllmsg = nil

platoon = {}

def ex_null(arg)
  return 'null' unless arg
  return arg
end

class PLedit
  def initialize(id, desc, cap, leader, member = [], queue = [], time = nil)
    #channel id    
    #{ch_id => {user_id => member_name}}
    url = ENV['DATABASE_URL'] #if ENV['DATABASE_URL']
    uri = URI.parse(url)
    @db = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    @id = id.to_i; @desc = desc; @cap = cap.to_i; @leader = leader.to_i; @plmember = member; @plqueue = queue
    @leader = 'null' if @leader == 0
    unless time
      @timestamp = Time.now
      @db.exec("insert into plat (leader, member_id_list, queue_id_list, channel_id, description, cap, created_at) values (#{leader}, '#{member.join('-')}', '#{queue.join('-')}', #{id}, '#{desc}', #{cap.to_i}, #{@timestamp.to_i});")
    else
      @timestamp = Time.at(time.to_i)
    end
  end
  
  def break_pl
    @db.exec("delete from plat where channel_id = #{@id};")
    @id = 0; @desc = nil; @cap = 0; @leader = nil; @plmember = []; @plqueue = []
    #@plleader.delete(ch_id); @plmember.delete(ch_id); @plqueue.delete(ch_id)
  end

  def join_member(member_id)
    #return 'exist' if @plqueue.keys.include?(member.id)
    #p @leader, member.id, @plmember
    return 'full' if @cap <= @plmember.size
    if @plqueue.include?(member_id)
      @plqueue.delete(member_id)
      @plmember.push(member_id)
      @db.exec("update plat set queue_id_list = '#{@plqueue.join('-')}', member_id_list = '#{@plmember.join('-')}' where channel_id = #{@id};")
      return 'queue'
    elsif @plmember.include?(member_id)
      return nil#'you are member'
    elsif @leader == member_id
      @leader = 'null'
      @plmember.push(member_id)
      @db.exec("update plat set leader = #{@leader}, member_id_list = '#{@plmember.join('-')}' where channel_id = #{@id};")
      return 'leader'
    else
      @plmember.push(member_id)
      @db.exec("update plat set member_id_list = '#{@plmember.join('-')}' where channel_id = #{@id};")
      return 'member'
    end
    return 'ok'
  end

  def join_queue(member_id)
    #return 'exist' if @plqueue.keys.include?(member_id)
    if @plqueue.include?(member_id)
      return nil#'you are in queue'
    elsif @plmember.include?(member_id)
      @plmember.delete(member_id)
      @plqueue.push(member_id)
      @db.exec("update plat set queue_id_list = '#{@plqueue.join('-')}', member_id_list = '#{@plmember.join('-')}' where channel_id = #{@id};")
      return 'member'
    elsif @leader == member_id
      @leader = 'null'
      @plqueue.push(member_id)
      @db.exec("update plat set leader = #{@leader}, queue_id_list = '#{@plqueue.join('-')}' where channel_id = #{@id};")
      return 'leader'
    else
      @plqueue.push(member_id)
      @db.exec("update plat set queue_id_list = '#{@plqueue.join('-')}' where channel_id = #{@id};")
      return 'queue'
    end
    return 'ok'
  end

  def leave(member_id)
    #return 'exist' if @plqueue.keys.include?(member_id)
    if @plqueue.include?(member_id)
      @plqueue.delete(member_id)
      @db.exec("update plat set queue_id_list = '#{@plqueue.join('-')}' where channel_id = #{@id};")
      return 'queue'
    elsif @plmember.include?(member_id)
      @plmember.delete(member_id)
      @db.exec("update plat set member_id_list = '#{@plmember.join('-')}' where channel_id = #{@id};")
      return 'member'
    elsif @leader == member_id
      @leader = 'null'
      @db.exec("update plat set leader = #{@leader}, member_id_list = '#{@plmember.join('-')}' where channel_id = #{@id};")
      return 'leader'
    else
      return nil#'not member'
    end
    #self.break_pl unless self.read_status
    return 'ok'
  end

  def leader(member_id)
    return nil if @leader != 'null'
    #member_id = member_id
    if @plqueue.include?(member_id)
      @plqueue.delete(member_id)
      @leader = member_id
      @db.exec("update plat set queue_id_list = '#{@plqueue.join('-')}', leader = #{@leader} where channel_id = #{@id};")
    elsif @plmember.include?(member_id)
      @plmember.delete(member_id)
      @leader = member_id
      @db.exec("update plat set member_id_list = '#{@plmember.join('-')}', leader = #{@leader} where channel_id = #{@id};")
    elsif @leader == member_id
      return 'you are leader'
    else
      return false #'join first'
    end
    return 'ok'
  end

  def cap(num)
    old_cap = @cap.to_i
    @cap = num.to_i
    return old_cap
  end

  def plat_exists?
    res = @db.exec("select id from plat where channel_id = #{@id};")
    res.each do |row|
      return true if row['id']
    end
    return false
  end

  def read_leader(use_cache = true)
    @plleader if use_cache
  end

  def read_member(use_cache = true)
    @plmember if use_cache
  end

  def read_queue(use_cache = true)
    @plqueue if use_cache
  end

  def read_status(use_cache = true)
    #plleader = nil
    list = [@leader, @plmember, @plqueue]
    return nil if list.select{|c| !(c != 'null' || c != [])}.empty?
    return list
  end

  def status_template(mode, user = nil, act = nil)
    queue_count = nil; queue_count = "\n[順番待ち]:#{@plqueue.size}人" unless @plqueue.empty?
    queue_text = "#{queue_count} `#{@plqueue.map{|mid| NameCaller.read(mid)}.join('`, `')}`" if queue_count
    leader_name = nil; leader_name = NameCaller.read(@leader) if @leader != 'null'
    leader_text = "\n[リーダー]:none `type ;leader to be the leader`"; leader_text= "\n[リーダー]:`#{leader_name}`" if leader_name
    member_count = @plmember.size; member_count = @plmember.size + 1 if @leader != 'null'
    member_text = "\n[メンバー]:none `type ;join to join the platoon`"; member_text = "\n[メンバー]:`#{@plmember.map{|mem| NameCaller.read(mem)}.join('`, `')}`" unless @plmember.empty?
    case mode
    when 0
      return "🎩**[info] :** `#{NameCaller.read(user)}`が小隊に#{act}しました\n🎩**[info] :** [参加人数]:`#{member_count}/#{@cap}`#{queue_count}"
    when 1
      return "🎩**[info] :**現在の小隊すてーたス\n[小隊名]:#{@desc}#{leader_text}#{member_text}#{queue_text}"
    when 2
      return "🎩**[info] :** 小隊名:#{@desc} #{leader_text}\nメンバー:`member`#{queue_count}"
    else
      'error: unknown template mode'
    end
  end

  def pll
    #plnow = ' 🈳 未編成'
    leader_count = 0; leader_count = 1 if @leader != 'null'
    member_count = @plmember.size; member_count = @plmember.size + leader_count if @leader != 'null'
    plstat = '🈳'; plstat = '🈵' if @plmember.size >= @cap + 1

    plnow = "#{plstat} #{@desc}"# if $platoon_name[0] != ''
    queue_text = nil; queue_text = " `順番待ち:#{@plqueue.size}人`" unless @plqueue.empty?
    plnum = "`#{@plmember.size + leader_count}/#{@cap + 1}`"# if $platoon1_member.size != 0
    #pllmsg = bot.channel(pllch).history(100).select{|m| m.author.id == BOT_ID}.first
    return "<##{@id}> **:**#{plnow}#{plnum}#{queue_text}"
  end

  def self.return_platoon_data
    platoon_hash = {}
    url = ENV['DATABASE_URL'] if ENV['DATABASE_URL']
    uri = URI.parse(url)
    db = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    res = db.exec("select * from plat;")
    res.each do |row|
      ch_id = row['channel_id'].to_i
      platoon_hash[ch_id] = self.new(ch_id, row['description'], row['cap'], row['leader'], row['member_id_list'].split('-').map{|n| n.to_i}, row['queue_id_list'].split('-').map{|n| n.to_i}, row['created_at'])
    end
    return platoon_hash
  end
end

class NameCaller
  url = ENV['DATABASE_URL']
  uri = URI.parse(url)
  @db = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)

  def self.read(id)
    res = @db.exec("select name from name where id = #{id};")
    res.each do |row|
      if row.key?('name')
        return row['name']
      else
        return nil
      end
    end
    nil
  end

  def self.write(id, name)
    res = @db.exec("select id from name where id = #{id};")
    res.each do |row|
      if row.key?('id')
        @db.exec("update name set id = #{id}, name = '#{name}' where id = #{id};")
      else
        @db.exec("insert into name(id, name) values(#{id}, '#{name}');")
      end
    end
  end

  def self.exist?(id)
    res = @db.exec("select id from name where id = #{id}")
    res.each do |row|
      return true
    end
    return false
  end
end

def create_lobby_mes(platoon, plchannels)
  lobby_mes = plchannels.map do |pl_ch|
    pl = platoon[pl_ch]
    next pl.pll if pl
    "<##{pl_ch}> **:** 小隊未編成"
  end
  return "🎩小隊情報\n#{lobby_mes.join("\n")}"
end

bot.ready do |e|
  platoon = PLedit.return_platoon_data
  bot.game = ('Robocraft')
  pllmsg = bot.channel(pllch).history(100).select{|m| m.author.id == bot.profile.id}.first
  
  lobby_mes = create_lobby_mes(platoon, plchannels)
  if pllmsg
    pllmsg.edit(lobby_mes)
  else
    pllmsg = bot.send_message(pllch, lobby_mes)
  end
  p platoon
end

bot.command([:c, :create], {channels: plchannels}) do |e, *args|
  cap = 4
  desc = nil
  if args[1].to_i > 0
    desc = args.first
    cap = args[1].to_i
  else
    desc = args.join(' ')
  end
  leader = e.user.id; member = []; queue = []
  ch_id = e.channel.id
  NameCaller.write(leader, e.user.name) unless NameCaller.exist?(leader)
  if platoon.key?(ch_id)
    return 'platoon exists'
  else
    platoon[ch_id] = PLedit.new(ch_id, desc, cap, leader, member, queue)
    e.respond('platoon created')
  end
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  nil
end

bot.command([:b, :break], {channels: plchannels}) do |e, *args|
  ch_id = e.channel.id
  if platoon.key?(ch_id)
    platoon[ch_id].break_pl
    platoon.delete(ch_id)
    e.respond('breaked platoon')
  else
    e.respond('there is no platoon')
  end
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  nil
end

bot.command([:j, :join], {channels: plchannels}) do |e|
  ch_id = e.channel.id
  member = e.user
  return "error: no platoon" unless platoon.key?(ch_id)
  NameCaller.write(member.id, member.name) unless NameCaller.exist?(member.id)
  res = platoon[ch_id].join_member(member.id)

  case res
  when 'close'
    return "error: platoon closed" 
  when 'full'
    return "error: platoon is full"
  when 'queue'
    platoon[ch_id].join_queue(member.id)
    e.respond "info: added queue(over capacity)"
  when 'leader'
    e.respond "info: your role is changed from leader to member"
  when nil
    return "error: youre already member"
  else
    'done'
  end
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  nil
end

bot.command([:l, :leave], {channels: plchannels}) do |e|
  ch_id = e.channel.id
  member = e.user
  return "no platoon error" unless platoon.key?(ch_id)
  res = platoon[ch_id].leave(member.id)
  mes = nil
  case res
  when 'member'
    mes = "info: left from member list" 
  when 'queue'
    mes = "info: left from queue list"
  when 'leader'
    mes = "info: leader left"
  when nil
    return "error: youre not member or in any queue"
  else
    'exception'
  end
  p platoon[ch_id].read_status
  unless platoon[ch_id].read_status
    platoon[ch_id].break_pl
    platoon.delete(ch_id)
    e.respond "platoon dismissed"
  else
    e.respond mes
  end
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  nil
end

bot.command([:kick, :bye, :byebye, :sayonara], {channels: plchannels}) do |e, *args|
  ch_id = e.channel.id
  member = e.user
  return "no platoon error" unless platoon.key?(ch_id)
  res = platoon[ch_id].leave(member.id)
  case res
  when 'member'
    e.respond "info: kicked from member list" 
  when 'queue'
    e.respond "info: kicked from queue list"
  when 'leader'
    e.respond "info: leader was kicked from platoon!!??!?!?!?!??"
  when nil
    return "error: youre not member or in any queue"
  else
    'exception'
  end
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  nil
end

bot.command([:p, :queue], {channels: plchannels}) do |e|
  ch_id = e.channel.id
  member = e.user
  return "no platoon error" unless platoon.key?(ch_id)
  NameCaller.write(member.id, e.user.name) unless NameCaller.exist?(member.id)
  res = platoon[ch_id].join_queue(member.id)
  case res
  when 'close'
    return "error: platoon closed" 
  when 'member'
    e.respond "info: you are added from member to queue list"
  when 'queue'
    e.respond "info: added queue"
  when 'leader'
    e.respond "info: your role is changed from leader to queue"
  when nil
    return "error: youre already member"
  else
    'done'
  end
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  nil
end

bot.command(:add, {channels: plchannels}) do |e, *args|
  'you have no permission to execute this command'
end

bot.command(:name) do |e, new_name|
  #name = new_name#.join(' ')
  old_name = nil; old_name = NameCaller.read(e.author.id) if NameCaller.exist?(e.author.id)
  return "現在の登録内容と同一です" if old_name == new_name
  NameCaller.write(e.author.id, new_name)
  return "#{new_name}を登録しました" unless old_name
  "#{old_name}から#{new_name}に変更しました"
end

bot.comand([:cap, :capacity], {channels: plchannels}) do |e, num|
  ch_id = e.channel.id
  plat = platoon[ch_id]
  return 'there isno platoon' unless plat
  old_cap = plat.cap(num.to_i)
  "changed capacity to #{num} from #{old_cap}"
end

bot.command([:s, :status], {channels: plchannels}) do |e|
  ch_id = e.channel.id
  #platoon[ch_id].status_template(0, e.user.id, '参加')
  return 'there is no platoon' unless platoon[ch_id]
  platoon[ch_id].status_template(1)
end

bot.command(:leader, {channels: plchannels}) do |e|
  ch_id = e.channel.id
  member = e.user
  return "no platoon error" unless platoon.key?(ch_id)
  return 'couldnt' unless platoon[ch_id].leader(member.id)
  e.respond 'now ur the leader'
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.edit(lobby_mes)
  nil
end

bot.command([:ad, :advertise], {channels: plchannels}) do |e|
  lobby_mes = create_lobby_mes(platoon, plchannels)
  pllmsg.delete
  pllmsg = bot.send_message(pllch, lobby_mes)
  'updated platoon lobby'
end

bot.command(:remove, {channels: plchannels}) do |e|
  'you have no permission to execute this command'
end

bot.command([:help, :h], {channels: plchannels}) do |e|
  mes = <<STR
`;c, ;create @platoon_name [@capacity]` create a new platoon
`;j, ;join` join the platoon if exists
`;l, ;leave` leave the platoon
`;b, ;break` break the platoon
`;s, ;status` show the platoon status
`;desc, ;description` change description of the platoon
`;add @mention ` add a mentioned user
`;p, ;queue` join the queue list of the platoon
`;leader` be a leader of the platoon
`;ad, ;advertise` update platoon lobby information message
`;kick, ;bye, ;byebye, ;sayonara @mention` kick a member or someone in queue list
`;help, ;h` show this message
STR
  mes
end

bot.command(:eval) do |e,*args|
  eval args.join(' ') if e.author.id == A7ID
end

bot.run

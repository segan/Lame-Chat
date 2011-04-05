#!/usr/bin/env ruby -w

require 'rubygems'
require 'eventmachine'

class CmdExecutor < EM::Connection
  include EM::P::LineText2

  attr_reader   :port
  attr_reader   :cmd_prompt
  attr_reader   :rsp_prefix
  attr_reader   :greetings
  attr_reader   :chan
  attr_accessor :chan_sid

  def initialize port, chan, *args
    p port, chan, args
    @port = port
    @chan = chan
    @cmd_prompt = "[#{port}]> "
    @rsp_prefix = "[#{port}]# "
    @greetings = "Hello how may I be of assistance?"
    console "Setting port=#{@port}"
    console "Setting prompt=#{@cmd_prompt}"
    console "#{self.class} initialized"
  end
  def console *args
    puts "[#{port}] #{args.join(' ')}"
  end
  def send_line line
    send_data(line+"\n")
  end
  def post_init
    console "\"post_init\" for port=#{port}"
    self.chan_sid = chan.subscribe { |msg| receive_chan msg }
    console "channel sid = ##{chan_sid}"
    send_line greetings
    send_data cmd_prompt
  end
  def receive_chan msg
    (chan_sid_sender, port, cmd, *args) = *msg;
    return if chan_sid_sender == chan_sid
    console "FROM CHANNEL: (#{chan_sid_sender},#{port}) #{cmd} #{args.join ' '}"
    send_line rsp_prefix + "#{cmd} #{args.join ' '}"
  end
  def receive_line line
    (cmd, *args) = line.split(' ')
    cmd = cmd.downcase
    console "RECIEVED CMD: #{cmd} #{args.join(' ')}"
    case cmd
    when "close"
      console "\"close\" command called"
      console "close_connection will be issued"
      send_line rsp_prefix + cmd
      close_connection_after_writing
    when "quit"
      console "\"quit\" command called"
      console "EM.stop will be issued"
      send_line rsp_prefix + cmd
      EM.next_tick { EM.stop }
    else
      chan.push([chan_sid, port, cmd, *args])
      console "sent to channel \"#{cmd} #{args.join ' '}\""
      send_data cmd_prompt
    end #case data
  end #end def recieve_data
  def unbind
    console "connection closed"
    chan.unsubscribe(chan_sid)
  end
  #private
end


EM.run {
  chan = EM::Channel.new
  EM.start_server("0.0.0.0", 7000, CmdExecutor, 7000, chan)
  EM.start_server("0.0.0.0", 7001, CmdExecutor, 7001, chan)
}


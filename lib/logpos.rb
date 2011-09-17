class Logpos
  VERSION = '1.0.1'

  begin; require 'chronic'; rescue LoadError; end
  TIME_PARSER_CLASS = if defined? Chronic
                        Chronic
                      else
                        require 'active_support'
                        Time
                      end


  attr_accessor :time_parser
  def initialize
    @time_parser = proc {|line| line.match(/^Started/) && TIME_PARSER_CLASS.parse(line.split(/for [0-9\.]* at /)[-1]) }
  end

  def self.seek_pos_before log_path, lastest_visited_at
    Logpos.new.seek_pos_before log_path, lastest_visited_at
  end

  def seek_pos_before log_path, lastest_visited_at
    ta = TripleArray.new lastest_visited_at

    log = File.open(log_path)
    pos_start, pos_end = 0, File.size(log)
    pos_mid = pos_end / 2
    time = Time.at(0)
    between = -1.0/0

    loop do
      pos_mid, time = seek_log_pos(log, pos_mid)
      break if time.nil? || (pos_mid == pos_end)

      time_valid = lastest_visited_at >= time
      break if time_valid && ((lastest_visited_at - time) >= between.abs)
      between = lastest_visited_at - time
      break if time_valid && ta.push(pos_mid, time).nil?

      if between > 0
        pos_start = pos_mid
        pos_mid = (pos_mid + pos_end) / 2
      elsif between < 0
        pos_end = pos_mid
        pos_mid = (pos_mid + pos_start) / 2
      end
    end

    return ta.oldest.pos
  end

  private
  def seek_log_pos log, pos
    log.seek pos
    log_size = File.size(log)

    loop do
      line = log.gets.to_s.strip!.to_s
      return log_size if log.pos >= log_size
      next if (time = @time_parser.call(line)).nil?
      return [log.pos, time]
    end
  end

  class TripleArray
    TP = Struct.new(:pos, :time)
    def initialize lastest_visited_at
      @lastest_visited_at = lastest_visited_at
      @array = Array.new(3, TP.new(0, Time.at(0)))
    end

    def push time, pos
      return nil if include? time

      @array[0..1] = @array[1..2]
      @array[2] = TP.new(time,  pos)
      @array
    end

    def include? time
      !!@array.detect {|tp| tp.time == time }
    end

    def oldest
      @array.select {|a| a.time <= @lastest_visited_at }.sort {|a, b| a.time <=> b.time}[-1]
    end
  end
end

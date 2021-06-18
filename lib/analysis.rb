require "pry"

class Block
  attr_reader :file, :s, :e, :data

  def initialize(file, s, e)
    @file = file
    @s = s
    @e = e
    @data = file[@s...@e]
  end

  def range
    "%06d-%06d" % [s, e-1]
  end

  def inspect
    "#{self.class}[#{@s}...#{@e}]"
  end

  def report
    puts "#{range} #{self.class} #{data.inspect}"
  end

  def <=>(other)
    [s,e] <=> [other.s, other.e]
  end
end

class DataBlock < Block
  def report
    puts "#{range} #{self.class}"
    data.chars.each_slice(16) do |slice|
      slice = slice.join
      asc = slice.chars.map{|c| c =~ /[\x20-\x7f]/ ? c : "."}.join
      asc += " " * (16 - asc.size)
      hex = slice.bytes.map{|c| "%02x" % c}.join(" ")
      puts "  #{asc} #{hex}"
    end
  end
end

class VersionBlock < Block
  def report
    puts "#{range} #{self.class} #{data[7,3].to_i}"
  end
end

class StringBlock < Block
  def report
    puts "#{range} #{self.class} #{data[2..-1].inspect}"
  end
end

class UnicodeBlock < Block
  def report
    puts "#{range} #{self.class} #{data[2..-1].unpack("v*").pack("U*").inspect}"
  end
end

class ImagePathBlock < StringBlock
end

class Analysis
  attr_reader :data, :size, :blocks

  def initialize(path)
    @data = path.read.b
    @size = @data.size
    @blocks = []
  end

  def call
    analysis
    report
  end

  def analysis
    if @data[0...10] =~ /\AVersion\d\d\d/
      @blocks << VersionBlock.new(self, 0, 10)
    end

    # Find all StringBlock and UnicodeBlock
    ofs = 10
    while ofs < size-2
      sz = @data[ofs, 2].unpack1("v")
      if sz < 4
        ofs += 1
        next
      end

      str = @data[ofs+2, sz]
      if str.size == sz and str =~ /\A[\r\n\t\x20-\x7f]+\z/
        if str =~ /(\.png|\.tga)\z/ and str =~ %r[/|\\]
          @blocks << ImagePathBlock.new(self, ofs, ofs+2+sz)
        else
          @blocks << StringBlock.new(self, ofs, ofs+2+sz)
        end
        ofs += 2 + sz
        next
      end

      ustr = @data[ofs+2, sz*2]
      if ustr.size == 2*sz and ustr =~ /\A(?:[\r\n\t\x20-\x7f]\x00)+\z/
        @blocks << UnicodeBlock.new(self, ofs, ofs+2+sz*2)
        ofs += 2 + sz * 2
        next
      end

      ofs += 1
    end
  end

  def report
    ofs = 0
    # Blocks can have gaps and occasionally overlap
    @blocks.sort.each do |b|
      if b.s > ofs
        report_data_block ofs, b.s
        ofs = b.s
      elsif b.s < ofs
        warn_overlap ofs, b.s
        ofs = b.s
      end
      b.report
      ofs = b.e
    end
    if ofs < size
      report_data_block ofs, size
    end
  end

  def report_data_block(s,e)
    DataBlock.new(self,s,e).report
  end

  def warn_overlap(ofs, new_ofs)
    puts "#{ofs}..#{new_ofs} BLOCK OVERLAP"
  end

  def [](*args)
    @data[*args]
  end
end

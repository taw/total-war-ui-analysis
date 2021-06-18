class Block
  attr_reader :file, :s, :e, :data

  def initialize(file, s, e)
    @file = file
    @s = s
    @e = e
    @data = file[@s...@e]
  end

  def range
    "#{s}..#{e-1}"
  end

  def inspect
    "#{self.class}[#{@s}...#{@e}]"
  end

  def report
    puts "#{range} #{self.class} #{data.inspect}"
  end
end

class DataBlock < Block
  def report
    puts "#{range} #{self.class}"
    data.chars.each_slice(16) do |slice|
      slice = slice.join
      asc = slice.chars.map{|c| c =~ /[\x20-x7f]/ ? c : "."}.join
      hex = slice.bytes.map{|c| "%02x" % c}.join(" ")
      puts "  #{asc} #{hex}"
    end
  end
end

class VersionBlock < Block
end

class StringBlock < Block
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
    # ...
  end

  def report
    ofs = 0
    # Blocks can have gaps and occasionally overlap
    @blocks.sort.each do |b|
      if b.start > ofs
        report_data_block ofs, b.s
        ofs = b.s
      elsif b.s < ofs
        warn_overlap ofs, b.s
        ofs = b.s
      end
      b.report
      ofs = b.e
    end
    if ofs <= size
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

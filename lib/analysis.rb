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
  attr_reader :str

  def initialize(*)
    super
    @str = data[2..-1]
  end

  def report
    puts "#{range} #{self.class} #{str.inspect}"
  end
end

class UnicodeBlock < Block
  def report
    puts "#{range} #{self.class} #{data[2..-1].unpack("v*").pack("U*").inspect}"
  end
end

class ImagePathBlock < StringBlock
end

class T0Block < StringBlock
end

class FontNameBlock < StringBlock
end

class RootIDBlock < Block
  def report
    puts "#{range} #{self.class} #{data.unpack1("V")}"
  end
end

class ImageBlock < Block
  def report
    id = data[0,4].unpack1("V")
    str = data[6...-12]
    xsize = data[-12,4].unpack1("V")
    ysize = data[-8,4].unpack1("V")
    unknown = data[-4,4].unpack1("V")
    puts "#{range} #{self.class} id=#{id} xsize=#{xsize} ysize=#{ysize} path=#{str.inspect} unknown=#{unknown}"
  end
end

class EventListBlock < Block
  attr_reader :list
  attr_writer :s

  def initialize(*)
    super
    @list = []
  end

  def report
    puts "#{range} #{self.class} #{@list.inspect}"
  end
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

  def analyze_version
    if @data[0...10] =~ /\AVersion\d\d\d/
      add_block 0, 10, VersionBlock
      @version = @data[7,3].to_i
    else
      warn "File does not start with version block"
    end
  end

  # Not present in newest versions
  def analyze_rootid
    if @data[14,6] == "\x04\x00root".b
      add_block 10, 14, RootIDBlock
    end
  end

  def add_block(s, e, type)
    @blocks << type.new(self, s, e)
  end

  def analyze_strings
    # Find all StringBlock and UnicodeBlock
    # It skips some short ones, and definitely skips empty ones
    # TODO: We can find some of short ones later based on context
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
          add_block ofs, ofs+2+sz, ImagePathBlock
        elsif str =~ /\A(FiraSans-Regular|bardi_\d.*|Ingame \d+,|Frontend \d+,|la_gioconda|Norse\z|Norse-Bold)/
          add_block ofs, ofs+2+sz, FontNameBlock
        elsif str =~ /\A(normal_t0|[a-z_]+_t0)\z/
          add_block ofs, ofs+2+sz, T0Block
        elsif str == "events_end"
          add_block ofs, ofs+2+sz, EventListBlock
        else
          add_block ofs, ofs+2+sz, StringBlock
        end
        ofs += 2 + sz
        next
      end

      ustr = @data[ofs+2, sz*2]
      if ustr.size == 2*sz and ustr =~ /\A(?:[\r\n\t\x20-\x7f]\x00)+\z/
        add_block ofs, ofs+2+sz*2, UnicodeBlock
        ofs += 2 + sz * 2
        next
      end

      ofs += 1
    end
  end

  def free_space_before(i)
    e = @blocks[i].s
    s = (i == 0) ? 0 : @blocks[i-1].e
    e - s
  end

  def free_space_after(i)
    s = @blocks[i].e
    e = (i == @blocks.size-1) ? @size : @blocks[i+1].s
    e - s
  end

  def analyze_images
    @blocks.each_with_index do |b,i|
      next unless b.is_a?(ImagePathBlock)
      next unless free_space_before(i) >= 4
      next unless free_space_after(i) >= 12
      xsize = @data[@blocks[i].e, 4].unpack1("V")
      ysize = @data[@blocks[i].e+4, 4].unpack1("V")
      next if xsize >= 0x1_0000
      next if ysize >= 0x1_0000
      @blocks[i] = ImageBlock.new(self, b.s-4, b.e+12)
    end
  end

  def analyze_image_lists
    # TODO
  end

  def analyze_event_lists
    @blocks.each_with_index do |b,i|
      next unless b.is_a?(EventListBlock)
      j = i-1
      while true
        break if j < 0
        if @blocks[j].is_a?(StringBlock) and @blocks[j].e == @blocks[i].s
          # eat it!
          @blocks[i].s = @blocks[j].s
          @blocks[i].list.unshift @blocks[j].str
          @blocks[j] = nil
          j -= 1
        else
          # don't try anything funny for now
          break
        end
      end
    end
    @blocks.compact!
  end

  def analysis
    analyze_version
    analyze_rootid
    analyze_strings
    analyze_images
    analyze_image_lists
    analyze_event_lists
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

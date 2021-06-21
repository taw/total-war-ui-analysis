require "pry"
require "set"

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

  def to_s
    "#{range} #{self.class} #{data.inspect}"
  end

  def <=>(other)
    [s,e] <=> [other.s, other.e]
  end
end

class DataBlock < Block
  def to_s
    "#{range} #{self.class}\n" +
    data.chars.each_slice(16).map do |slice|
      slice = slice.join
      asc = slice.chars.map{|c| c =~ /[\x20-\x7f]/ ? c : "."}.join
      asc += " " * (16 - asc.size)
      hex = slice.bytes.map{|c| "%02x" % c}.join(" ")
      "  #{asc} #{hex}\n"
    end.join
  end
end

class VersionBlock < Block
  def to_s
    "#{range} #{self.class} #{data[7,3].to_i}"
  end
end

class Uint32Block < Block
  def to_s
     "#{range} #{self.class} #{data.unpack1("V")}"
  end
end

class StringBlock < Block
  attr_reader :str

  def initialize(*)
    super
    @str = data[2..-1]
  end

  def to_s
    "#{range} #{self.class} #{str.inspect}"
  end
end

class UnicodeBlock < Block
  def to_s
    "#{range} #{self.class} #{data[2..-1].unpack("v*").pack("U*").inspect}"
  end
end

class ImagePathBlock < StringBlock
end

class T0Block < StringBlock
end

class FontNameBlock < StringBlock
end

class NewStateBlock < StringBlock
end

class XOffsetBlock < Uint32Block
end

class YOffsetBlock < Uint32Block
end

class StateIDBlock < Uint32Block
end

class U32ListBlock < Block
  attr_reader :blocks

  def initialize(file, s, e, blocks)
    super(file, s, e)
    @count = data[0,4].unpack1("V")
    @blocks = blocks
    # verify that block list is correct
    raise unless blocks.size == @count
    raise unless blocks.first.s == s+4
    raise unless blocks.last.e == e
    raise unless blocks.each_cons(2).all?{|a,b| a.e == b.s}
  end

  def to_s
    "#{range} #{self.class} #{@count} elements:\n" +
    @blocks.map(&:to_s).join("\n").gsub(/^/, "  ")
  end
end

class ImageBlock < Block
  attr_reader :id

  def initialize(*)
    super
    @id = data[0,4].unpack1("V")
    @str = data[6...-12]
    @xsize = data[-12,4].unpack1("V")
    @ysize = data[-8,4].unpack1("V")
    @unknown = data[-4,4].unpack1("V")
  end

  def to_s
    "#{range} #{self.class} id=#{@id} xsize=#{@xsize} ysize=#{@ysize} path=#{@str.inspect} unknown=#{@unknown}"
  end
end

class ImagePathListBlock < U32ListBlock
end

class ImageListBlock < U32ListBlock
end

class EventListBlock < Block
  attr_reader :list
  attr_writer :s

  def initialize(*)
    super
    @list = []
  end

  def to_s
     "#{range} #{self.class} #{@list.inspect}"
  end
end

class RootIDBlock < Uint32Block
end

class XSizeBlock < Uint32Block
end

class YSizeBlock < Uint32Block
end

class ImageUseBlock < Block
  def initialize(*)
    super
    @id = data[0,4].unpack1("V")
    @xofs = data[4,4].unpack1("V")
    @yofs = data[8,4].unpack1("V")
    @xsize = data[12,4].unpack1("V")
    @ysize = data[16,4].unpack1("V")
    @brga = data[20,4].unpack1("V")
  end

  def to_s
    "#{range} #{self.class} id=#{@id} xofs=#{@xofs} yofs=#{@yofs} xsize=#{@xsize} ysize=#{@ysize} brga=#{@brga}"
  end
end

class Version002FileBlock < Block
  def initialize(file, s, e, strs)
    super(file, s, e)
    @strs = strs
  end

  def to_s
    "#{range} #{self.class}\n" +
    @strs.each_slice(2).map do |k,v|
      "  KEY #{k.inspect}\n  VALUE #{v.inspect}\n"
    end.join
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
        elsif str =~ /\A(FiraSans-Regular|bardi_\d.*|Ingame \d+,|Frontend \d+,|la_gioconda|Norse\z|Norse-Bold|Iskra-Bold|georgia_italic)/
          add_block ofs, ofs+2+sz, FontNameBlock
        elsif str =~ /\A(normal_t0|[a-z_]+_t0)\z/
          add_block ofs, ofs+2+sz, T0Block
        elsif str == "events_end"
          add_block ofs, ofs+2+sz, EventListBlock
        elsif str == "NewState"
          add_block ofs, ofs+2+sz, NewStateBlock
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

  # blocks can be temporarily nil during rewriting
  def free_space_before(i)
    prev = i-1
    while prev != 0 and @blocks[prev].nil?
      prev -= 1
    end
    e = @blocks[i].s
    s = (i == 0) ? 0 : @blocks[prev].e
    e - s
  end

  def free_space_after(i)
    s = @blocks[i].e
    e = (i == @blocks.size-1) ? @size : @blocks[i+1].s
    e - s
  end

  def free_space?(s, e)
    return false if s < 0
    return false if e > @size
    @blocks.all?{|b|
      b.e <= s or b.s >= e
    }
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

  def analyze_u32_lists(base_class, list_class)
    @blocks.each_with_index do |b,i|
      next unless b.is_a?(base_class)
      next unless free_space_before(i) >= 4
      count = @data[b.s-4, 4].unpack1("V")
      next unless count >= 1
      subblocks = @blocks[i, count]
      next unless subblocks.size == count
      next unless subblocks.all?{|bb| bb.is_a?(base_class)}
      next unless subblocks.each_cons(2).all?{|u,v| u.e == v.s}
      s = subblocks.first.s - 4
      e = subblocks.last.e
      new_block = list_class.new(self, s, e, subblocks)
      @blocks[i] = new_block
      ((i+1)...(i+count)).each do |j|
        @blocks[j] = nil
      end
    end
    @blocks.compact!
  end

  def analyze_version_2
    strs = []
    ofs = 10
    while ofs < size
      return if ofs + 2 > size
      sz = @data[ofs,2].unpack1("v")
      ofs += 2
      return if ofs + sz > size
      strs << @data[ofs,sz]
      ofs += sz
    end
    return if strs.size.odd?
    @blocks << Version002FileBlock.new(self, 10, size, strs)
  end

  def analyze_new_state_context
    i = 0
    while i < @blocks.size
      b = @blocks[i]
      if b.is_a?(NewStateBlock) and free_space_after(i) >= 8 and free_space_before(i) >= 4
        s = b.s
        e = b.e
        xsz = @data[e,4].unpack1("V")
        ysz = @data[e+4,4].unpack1("V")
        if xsz < 0x1_0000 and ysz < 0x1_0000
          @blocks[i,1] = [
            StateIDBlock.new(self, s-4, s),
            @blocks[i],
            XSizeBlock.new(self, e, e+4),
            YSizeBlock.new(self, e+4, e+8),
          ]
          i += 3
        end
      end
      i += 1
    end
  end

  def analyze_image_uses
    image_blocks = @blocks.grep(ImageListBlock).flat_map(&:blocks) + @blocks.grep(ImageBlock)
    block_ids = image_blocks.map(&:id).map{|u| [u].pack("V") }.to_set
    indexes = []
    (0...@size-4).each do |i|
      if block_ids.include?(@data[i,4])
        indexes << i
      end
    end
    indexes.each do |i|
      if free_space?(i, i+24)
        add_block i, i+24, ImageUseBlock
      end
    end
    @blocks.sort_by!(&:s)
  end

  # This could apply to all uientity, but others are difficult to locate
  def analyze_root_context
    return unless @blocks[2].is_a?(StringBlock) and @blocks[2].e == 20 and @blocks[2].str == "root"
    ofs = 20
    block_idx = 2
    # title 2
    if free_space_after(block_idx) >= 2 and @version >= 43
      sz = @data[ofs, 2].unpack1("v")
      @blocks[block_idx,0] = StringBlock.new(self, ofs, ofs+2+sz)
      block_idx += 1
      ofs += 2+sz
    end
    if free_space_after(block_idx) >= 8
      @blocks[block_idx,0] = [
        XOffsetBlock.new(self, ofs, ofs+4),
        YOffsetBlock.new(self, ofs+4, ofs+8),
      ]
      block_idx += 1
      ofs += 8
    end
    # then some booleans etc.
  end

  def analysis
    analyze_version
    if @version == 2
      analyze_version_2
      return if fully_decoded?
    end
    analyze_rootid
    analyze_strings
    analyze_images
    analyze_event_lists
    analyze_u32_lists(ImageBlock, ImageListBlock)
    analyze_u32_lists(ImagePathBlock, ImagePathListBlock)
    analyze_new_state_context
    analyze_image_uses
    analyze_root_context
  end

  # some blocks aren't actually fully decoded and could use more processing
  # but mostly they'd have some undecoded data near them,
  # so we don't really need to check
  def fully_decoded?
    return false unless @blocks.first.s == 0
    return false unless @blocks.last.e == size
    @blocks.each_cons(2) do |a,b|
      return false unless a.e == b.s
    end
    true
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
      puts b
      ofs = b.e
    end
    if ofs < size
      report_data_block ofs, size
    end
  end

  def report_data_block(s,e)
    puts DataBlock.new(self,s,e)
  end

  def warn_overlap(ofs, new_ofs)
    puts "#{ofs}..#{new_ofs} BLOCK OVERLAP"
  end

  def [](*args)
    @data[*args]
  end
end

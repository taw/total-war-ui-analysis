require_relative "./file_task"

class TaskSet
  attr_reader :todo

  def initialize(*filter)
    @filter = filter
    @todo = []
    data_root.find do |path|
      next if path.directory?
      @todo << FileTask.new(path)
    end
  end

  def data_root
    Pathname(__dir__).parent + "data"
  end
end

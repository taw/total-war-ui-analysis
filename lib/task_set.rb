require_relative "./file_task"
require_relative "./task_filter"

class TaskSet
  attr_reader :todo

  def initialize(*filter)
    @filter = filter.map{|expr| TaskFilter.new(expr)}
    @todo = []
    data_root.find do |path|
      next if path.directory?
      @todo << FileTask.new(path)
    end
    apply_filter!
  end

  def data_root
    Pathname(__dir__).parent + "data"
  end

  def apply_filter!
    return if @filter.empty?
    @todo.select!{|task| @filter.any?{|f| f.match?(task)} }
    warn "No files selected" if @todo.empty?
  end
end

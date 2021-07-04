desc "Regenerate everything (slow!)"
task :regenerate do
  # should clean up .fail first
  sh "./bin/analyze_all_files"
  sh "./bin/convert_all_files"
  sh "./bin/unpack_all_files"
end

desc "List all errors"
task :errors do
  sh "git ls unpacked/*/*.fail | xargs cat | grep -a '<error'| perl -ple 's/^ +//' | sort | uniq -c"
end

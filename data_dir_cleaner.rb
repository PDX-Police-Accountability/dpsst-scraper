require 'csv'

def du_command(dir_name)
  "du -sb #{dir_name}/* | awk '{print $2,$1}' | sort"
end

def subdirectories(dir_name)
  cmd = du_command(dir_name)

  `#{cmd}`.split("\n")
end

def find_duplicates(dir_name)
  previous_size = ''

  subdirectories(dir_name).each_with_object([]) do |subdir, duplicates|
    dirname, dirsize = subdir.split

    if dirsize == previous_size
      duplicates.push(dirname)
    end

    previous_size = dirsize
  end
end

def clean_data_dir(dir_name = './scraped-data')
  duplicates = find_duplicates(dir_name)

  puts "==> Found #{duplicates.length} directories that are the same size as the previous directory."

  duplicates.each do |duplicate|
    cmd = "rm -rf #{duplicate}"
    `#{cmd}`
  end

  puts "==> Done"

  nil
end

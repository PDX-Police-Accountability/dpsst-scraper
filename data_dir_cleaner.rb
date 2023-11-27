require 'csv'

def du_command(dir_name)
  # "du -sb #{dir_name}/* | awk '{print $2,$1}' > ../sizes.txt"
  "du -sb #{dir_name}/* | awk '{print $2,$1}' | sort"
end

def officer_ids(filename = 'input-data/officers.csv')
  table = CSV.read(filename, { headers: true, col_sep: '|' })
  table['DPSST'].sort
end

def output_directory(date)
  directory = "scraped-data/#{date}"

  FileUtils.mkdir_p(directory) unless File.exists?(directory)

  directory
end


def clean_data_dir(dir_name = 'scraped-data')
  agency_name = 'Portland Police Bureau'
  date = Date.today.to_s + date_suffix

  dpsst_ids.each do |dpsst_id|
    scrape_one_officer_affiliation_with_retries(dpsst_id, agency_name, date)
  end
end

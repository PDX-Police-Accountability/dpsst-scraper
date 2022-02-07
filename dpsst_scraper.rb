require 'csv'
require 'ferrum'
require 'nokogiri'

def officer_ids(filename = 'input-data/officers.csv')
  table = CSV.read(filename, { headers: true, col_sep: '|' })
  table['DPSST']
end

def html_from_browser(browser)
  begin
    doc = Nokogiri::HTML(browser.body)
    doc.css('input[type="hidden"], link, script, #HeaderTable, table.Breadcrumb, table#CopyrightTable')&.remove

    doc.css('td.HeaderTitle, td.HeaderTitlePrint').each do |node|
      node.delete('style')
    end

    doc.css('tr.row, tr.rowAlt')&.each do |node|
      node.delete('class')
    end

    doc.css('td')&.each do |node|
      node.delete('align')
    end

    doc.to_xhtml(save_with: Nokogiri::XML::Node::SaveOptions::DEFAULT_HTML)
  rescue StandardError => e
    e.inspect
  end
end

def save_page_html(browser, dpsst_id, file_name_base, date)
  filename = "#{output_directory(date)}/#{dpsst_id}-#{file_name_base}.html"

  File.open(filename, 'w') do |f|
    html = html_from_browser(browser)
    f.write(html)
  end
end

def save_screenshot(browser, dpsst_id, file_name_base, date)
  browser.screenshot(path: "#{output_directory(date)}/#{dpsst_id}-#{file_name_base}.png")
end

def scrape_one_officer_affiliation(dpsst_id, date, row_index)
  n = row_index + 1
  puts "Scraping dpsst_id #{dpsst_id}, row #{n}"

  url = "https://www.bpl-orsnapshot.net/PublicInquiry_CJ/EmployeeSearch.aspx"
  browser = Ferrum::Browser.new
  browser.go_to(url)

  input = browser.at_xpath("//input[@id='rdoSearchOption_1']")
  input.click

  input = browser.at_xpath("//input[@id='txtNameSearch']")
  input.focus.type(dpsst_id)
  browser.at_css("#cmdSearch").click

  browser.network.wait_for_idle

  save_page_html(browser, dpsst_id, "index", date)

  # Make sure the requested row exists. Sometimes we get back 0 rows.
  begin
    rows = browser.css("table#gvwEmployees tr")
    row = rows[n]
    cell = row.css("td").first
    cell.click

    browser.network.wait_for_idle

    transcript_button_id = "ContentPlaceHolder1_cmdProfile"

    # You have to hit the Transcript button twice, for whatever strange reason.
    #
    # 1. Find and Click the button; wait for idle
    # 2. Find and Click the button
    # 3. Save the page html

    browser.at_css("input\##{transcript_button_id}").click
    browser.network.wait_for_idle
    browser.at_css("input\##{transcript_button_id}").click
    browser.network.wait_for_idle

    save_page_html(browser, dpsst_id, "transcript", date)
  rescue StandardError
    # save_screenshot(browser, dpsst_id, "#{n}-screenshot", date)
    puts "===> No rows in table for dpsst id #{dpsst_id} (scrape_one_officer_affiliation)"
  end

  browser.quit
end

# If an officer has multiple agency affiliations, we could
# use this to scrape each of the individual transcripts.
#
# At this time, it looks like each transcript is exactly the
# same.
#
# The only difference when looking at transcripts for the same
# officer with a different agency affiliation is the top part
# of the page which has redundant information from what is on
# their index page.
#
# For now, we'll just scrape the transcript from the first
# agency affiliation and we'll also scrape the index.
#
# So we should wind up with 2 html files for each officer:
#
# 1. index
# 2. transcript
def scrape_one_officer(dpsst_id, num_officer_agency_rows, date)
  if num_officer_agency_rows > 0
    scrape_one_officer_affiliation(dpsst_id, date, 0)
  end
end

# Get the number of rows in the officer's table of Name, ID, Agency Name, Rank/Position, Status
def scrape_one_officer_agency_row_count(dpsst_id)
  url = "https://www.bpl-orsnapshot.net/PublicInquiry_CJ/EmployeeSearch.aspx"
  browser = Ferrum::Browser.new
  browser.go_to(url)

  input = browser.at_xpath("//input[@id='rdoSearchOption_1']")
  input.click

  input = browser.at_xpath("//input[@id='txtNameSearch']")
  input.focus.type(dpsst_id)
  browser.at_css("#cmdSearch").click

  browser.network.wait_for_idle

  number_of_officer_agency_rows = 0

  begin
    rows = browser.css("table#gvwEmployees tr")
    number_of_officer_agency_rows = rows.count - 1
  rescue Ferrum::NodeNotFoundError
    puts "===> No rows in table for dpsst id #{dpsst_id} (scrape_one_officer_agency_row_count)"
  end

  browser.quit

  number_of_officer_agency_rows
end

def output_directory(date)
  directory = "scraped-data/#{date}"

  FileUtils.mkdir_p(directory) unless File.exists?(directory)

  directory
end

def scrape_dpsst
  date = Date.today.to_s

  # dpsst_ids = ["27981", "30864", "39600", "41483", "55152"]
  # dpsst_ids = ["61103"]
  dpsst_ids = officer_ids

  dpsst_ids.each do |dpsst_id|
    num_officer_agency_rows = scrape_one_officer_agency_row_count(dpsst_id)

    scrape_one_officer(dpsst_id, num_officer_agency_rows, date)
  end
end

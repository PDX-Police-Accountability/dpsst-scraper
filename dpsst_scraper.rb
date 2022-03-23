require 'csv'
require 'ferrum'
require 'nokogiri'

def officer_ids(filename = 'input-data/officers.csv')
  table = CSV.read(filename, { headers: true, col_sep: '|' })
  table['DPSST'].sort
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

# The only difference when looking at transcripts for the same
# officer with a different agency affiliation is the top part
# of the page which displays the officer's current status with
# the agency.
#
# We scrape the index to find all of an officer's agency
# affiliations and scrape the transcript associated with
# the desired agency.
#
# We should wind up with 1 transcript html file for each officer.
def scrape_one_officer_affiliation(dpsst_id, agency_name, date)
  puts "Scraping dpsst_id: #{dpsst_id}, agency_name: #{agency_name}"

  url = "https://www.bpl-orsnapshot.net/PublicInquiry_CJ/EmployeeSearch.aspx"
  browser = Ferrum::Browser.new
  browser.go_to(url)

  input = browser.at_xpath("//input[@id='rdoSearchOption_1']")
  input.click

  input = browser.at_xpath("//input[@id='txtNameSearch']")
  input.focus.type(dpsst_id)
  browser.at_css("#cmdSearch").click

  browser.network.wait_for_idle

  row_index = 1
  rows = browser.css("table#gvwEmployees tr")
  rows.each_with_index do |row, index|
    if row.text.include?('Portland Police Bureau')
      row_index = index
      break
    end
  end

  save_page_html(browser, dpsst_id, "index", date) if should_save_index_page?

  # Make sure the requested row exists. Sometimes we get back 0 rows.
  begin
    rows = browser.css("table#gvwEmployees tr")
    row = rows[row_index]
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

def output_directory(date)
  directory = "scraped-data/#{date}"

  FileUtils.mkdir_p(directory) unless File.exists?(directory)

  directory
end

# For debugging purposes, return true to save the index page
# along with each officer's transcript page.
def should_save_index_page?
  false
end

# For debugging purposes, return a non-empty string to keep
# from stomping on previously downloaded data from the same
# date.
def date_suffix
  ''
end

def scrape_dpsst
  agency_name = 'Portland Police Bureau'
  date = Date.today.to_s + date_suffix

  # Uncomment this and comment the following for debugging
  # subset of officers.
  # dpsst_ids = ["27981", "33125", "39600", "41483", "55152"]

  dpsst_ids = officer_ids

  dpsst_ids.each do |dpsst_id|
    scrape_one_officer_affiliation(dpsst_id, agency_name, date)
  end
end

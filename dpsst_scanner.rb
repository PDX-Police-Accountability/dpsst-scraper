require 'ferrum'
require 'nokogiri'

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

def scan_one_officer(dpsst_id, agency_name, date)
  puts "Scranning dpsst_id: #{dpsst_id}, agency_name: #{agency_name}"

  url = "https://www.bpl-orsnapshot.net/PublicInquiry_CJ/EmployeeSearch.aspx"
  browser = Ferrum::Browser.new

  # TODO: Sometimes we get this while waiting for idle::
  #
  #       Timed out waiting for response.
  #       It's possible that this happened because something took a very long time (for example a page load was slow).
  #       If so, setting the :timeout option to a higher value might help. (Ferrum::TimeoutError)

  begin
    browser.go_to(url)

    input = browser.at_xpath("//input[@id='rdoSearchOption_1']")
    input.click

    input = browser.at_xpath("//input[@id='txtNameSearch']")
    input.focus.type(dpsst_id)
    browser.at_css("#cmdSearch").click # NOTE: Have seen Ferrum::TimeoutError here.

    browser.network.wait_for_idle

    save_page_html(browser, dpsst_id, "index", date)
  rescue Ferrum::TimeoutError
    raise
  rescue StandardError => e
    puts "===> Error scanning dpsst id #{dpsst_id}: #{e.inspect}"
  ensure
    browser.quit
  end
end

def output_directory(date)
  directory = "scanned-data/#{date}"

  FileUtils.mkdir_p(directory) unless File.exists?(directory)

  directory
end

# For debugging purposes, return a non-empty string to keep
# from stomping on previously downloaded data from the same
# date.
def date_suffix
  ''
end

def scan_one_officer_with_retries(dpsst_id, agency_name, date)
  3.times do
    begin
      scan_one_officer(dpsst_id, agency_name, date)
      return
    rescue Ferrum::TimeoutError
      # Retry
    end
  end
end

def scan_range(agency_name, date, starting_id, ending_id)
  (starting_id.to_i..ending_id.to_i).each do |i|
    dpsst_id = i.to_s.rjust(5, '0')
    scan_one_officer_with_retries(dpsst_id, agency_name, date)
  end
end

def scan_dpsst(starting_id, ending_id)
  agency_name = 'Portland Police Bureau'
  date = Date.today.to_s + date_suffix

  scan_range(agency_name, date, starting_id, ending_id)
end

# README

The dpsst-scraper is a small Ruby script that pulls HTML from Oregon's [Criminal Justice Information Records Inquiry System (CJ IRIS)](https://www.bpl-orsnapshot.net/PublicInquiry_CJ/EmployeeSearch.aspx) and stores it for later processing by other tools.

Runs daily via cron as the first piece of the scraping and magnifying process.
<pre>
3 0 * * * BASH_ENV=~/.bashrc bash -l -c "cd /home/marc/work/dpsst-scraper && bundle exec ruby -r './dpsst_scraper.rb' -e 'scrape_dpsst'"
3 1 * * * BASH_ENV=~/.bashrc bash -l -c "cd /home/marc/work/dpsst-magnifier && ./scripts/processor.sh `date +\%F`"
</pre>

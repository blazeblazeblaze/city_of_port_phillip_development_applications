# frozen_string_literal: true

require 'mechanize'
require 'scraperwiki'

HEADERS = {
  'HTTP_USER_AGENT': 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.13) Gecko/2009073022 Firefox/3.0.13',
  'HTTP_ACCEPT': 'text/html,application/xhtml+xml,application/xml; q=0.9,*/*; q=0.8',
  'Content-Type': 'application/x-www-form-urlencoded'
}.freeze

BASE_URL = 'https://eservices.portphillip.vic.gov.au/ePathway/Production/Web/GeneralEnquiry'
HOMEPAGE_URL = BASE_URL + '/EnquiryLists.aspx'
RESULTS_URL = BASE_URL + '/EnquirySummaryView.aspx'

agent = Mechanize.new

# 1. Create session
sessionpage = agent.get(HOMEPAGE_URL, headers: HEADERS)
sessionpage.forms.first.radiobuttons[1].check # Select all applications
agent.submit(sessionpage.forms.first, sessionpage.forms.first.buttons.last) # Submit form

# 2. Retrieve number of pages to be scraped
pagination_page = agent.get(RESULTS_URL)
pagination_text = pagination_page.at('#ctl00_MainBodyContent_mPagingControl_pageNumberLabel').inner_text.strip
pages_count = pagination_text.scan(/\d+/).last.to_i

# 3. Scraping starts here
(1..pages_count).each do |page_number|
  page = agent.get("#{RESULTS_URL}?PageNumber=#{page_number}")
  table_rows = page.at('table.ContentPanel').search('tr.ContentPanel', 'tr.AlternateContentPanel')

  table_rows.each do |row|
    raw_data = row.search('td')

    record = {
      council_reference: raw_data[0].inner_text.strip,
      address: raw_data[2].inner_text.strip,
      description: raw_data[1].inner_text.strip,
      info_url: HOMEPAGE_URL,
      date_scraped: Date.today.to_s,
      date_received: Date.parse(raw_data[3].inner_text.strip).to_s
    }

    ScraperWiki.save_sqlite([:council_reference], record)
  end
end

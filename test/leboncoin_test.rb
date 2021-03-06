$: << __dir__ + '/../lib'

require 'minitest/autorun'
require 'vcr'
require 'leboncoin'

FIXTURES_DIR = __dir__ + '/fixtures'

VCR.configure do |conf|
  conf.cassette_library_dir = FIXTURES_DIR
  conf.hook_into :faraday
end

class LeboncoinTest < MiniTest::Unit::TestCase
  def test_search_raw
    url = 'http://www.leboncoin.fr/annonces/offres/ile_de_france/?f=a&th=1&q=rockrider+8.1'
    html = VCR.use_cassette('rockrider81') do
      Leboncoin.search_raw(url)
    end
    assert_equal Leboncoin::HTML_ENCODING, html.encoding
  end

  def test_search_raw_error
    exc = assert_raises Leboncoin::Error do
      VCR.use_cassette('404') do
        Leboncoin.search_raw('http://notfound')
      end
    end
    assert_match /: 404$/, exc.message
  end

  def test_parse_results
    html = File.read(FIXTURES_DIR + '/results.html', {encoding: Leboncoin::HTML_ENCODING})

    results = Leboncoin.parse_results(html)
    assert_equal 21, results.length

    res = results[0]
    assert_equal "VTT Rockrider 8.1 (350€ PRIX NEGOCIABLE)", res[:title]
    assert_kind_of Time, res[:time]
    assert_equal 350, res[:price]
    assert_equal "http://www.leboncoin.fr/velos/595226659.htm?ca=12_s", res[:url]
    assert_equal "http://193.164.196.60/images/695/695330119477510.jpg", res[:photo_url]
  end

  def test_parse_results_without_price
    html = File.read(FIXTURES_DIR + '/results_without_price.html', {encoding: Leboncoin::HTML_ENCODING})
    results = Leboncoin.parse_results(html)
    res = results[-2]
    assert_equal "Diaporama photos -- Montage vidéo", res[:title] # sanity check
    assert_nil res[:price]
  end

  def test_parse_results_without_photo
    html = File.read(FIXTURES_DIR + '/results_without_photo.html', {encoding: Leboncoin::HTML_ENCODING})
    results = Leboncoin.parse_results(html)
    res = results[-4]
    assert_equal "Iphone 4", res[:title] # sanity check
    assert_nil res[:photo_url]
  end
end

class LeboncoinResultTimeTest < MiniTest::Unit::TestCase
  def test_parse
    t = Time.now
    d, m, y = t.day, t.mon, t.year

    assert_lbc_time [6,11,y,17,59], "6 nov 17:59"
    assert_lbc_time [d,m,y,15,10], "Aujourd'hui 15:10"
    assert_lbc_time [d-1,m,y,22,43], "Hier 22:43"
    assert_lbc_time [27,12,y,21,57], "27 déc 21:57"
  end

  def test_parse_invalid_format
    exc = assert_raises Leboncoin::Error do
      Leboncoin::ResultTime.parse("27 INVALID 21:57")
    end
    assert_match /format: 27/, exc.message

    exc = assert_raises Leboncoin::Error do
      Leboncoin::ResultTime.parse("???")
    end
    assert_match /format: \?\?\?/, exc.message
  end

private

  def assert_lbc_time(expected, str)
    t = Leboncoin::ResultTime.parse(str)
    actual = [t.day, t.mon, t.year, t.hour, t.min]
    assert_equal expected, actual
  end
end

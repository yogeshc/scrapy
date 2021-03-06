#!/bin/bash
#
# This script is a quick system test for Scrapyd that:
#
# 1. runs scrapyd
# 2. creates a new project and deploys it on scrapyd
# 3. schedules a spider on scrapyd and waits for it to finish
# 4. check the spider scraped the expected data
#

set -e

export PATH=$PATH:$(pwd)/bin
export PYTHONPATH=$PYTHONPATH:$(pwd)

scrapyd_dir=$(mktemp /tmp/test-scrapyd.XXXXXXX -d)
scrapyd_log=$scrapyd_dir/scrapyd.log
scrapy_dir=$(mktemp /tmp/test-scrapy.XXXXXXX -d)

echo "scrapyd dir: $scrapyd_dir"
echo "scrapy dir : $scrapy_dir"

twistd -ny extras/scrapyd.tac -d $scrapyd_dir -l $scrapyd_log &

cd $scrapy_dir
scrapy startproject testproj
cd testproj
cat > testproj/spiders/insophia.py <<!
from scrapy.spider import BaseSpider
from scrapy.selector import HtmlXPathSelector
from scrapy.http import Request
from scrapy.item import Item, Field


class Section(Item):
    url = Field()
    title = Field()
    size = Field()
    arg = Field()


class InsophiaSpider(BaseSpider):
    name = 'insophia'
    start_urls = ['http://insophia.com']

    def __init__(self, *a, **kw):
        self.arg = kw.pop('arg')
        super(InsophiaSpider, self).__init__(*a, **kw)

    def parse(self, response):
        hxs = HtmlXPathSelector(response)
        for url in hxs.select('//ul[@id="navlist"]/li/a/@href').extract():
            yield Request(url, callback=self.parse_section)

    def parse_section(self, response):
        hxs = HtmlXPathSelector(response)
        title = hxs.select("//h2/text()").extract()[0]
        yield Section(url=response.url, title=title, size=len(response.body),
            arg=self.arg)
!

cat > scrapy.cfg <<!
[settings]
default = testproj.settings

[deploy]
url = http://localhost:6800/
project = testproj
!

scrapy deploy

curl -s http://localhost:6800/schedule.json -d project=testproj -d spider=insophia -d arg=SOME_ARGUMENT

echo "waiting 20 seconds for spider to run and finish..."
sleep 20

kill %1
wait %1

if ! grep -q "Process finished" $scrapyd_log; then
    echo "error: 'Process finished' not found on scrapyd log"
    exit 1
fi

feed_path=$(find $scrapyd_dir/items -name '*.jl')
if [ ! -f "$feed_path" ]; then
    echo "items feed not generated: $feed_path"
    exit 1
fi

log_path=$(find $scrapyd_dir/logs -name '*.log')
if [ ! -f "$log_path" ]; then
    echo "log file not generated: $log_path"
    exit 1
fi

numitems="$(cat $feed_path | wc -l)"
if [ "$numitems" != "7" ]; then
    echo "error: wrong number of items scraped: $numitems"
    exit 1
fi

numscraped="$(cat $log_path | grep Scraped | wc -l)"
if [ "$numscraped" != "7" ]; then
    echo "error: wrong number of 'Scraped' lines in log: $numscraped"
    exit 1
fi

if ! grep -q "About Us" $feed_path; then
    echo "error: About Us page not scraped"
    exit 1
fi

if ! grep -q "SOME_ARGUMENT" $feed_path; then
    echo "error: spider argument not found in scraped items"
    exit 1
fi

rm -rf /tmp/test-scrapyd.* /tmp/test-scrapy.*

echo "All tests OK"

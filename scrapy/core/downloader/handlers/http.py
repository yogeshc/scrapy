"""Download handlers for http and https schemes"""

from twisted.internet import reactor

from scrapy.exceptions import NotSupported
from scrapy.utils.misc import load_object
from scrapy import optional_features

ssl_supported = 'ssl' in optional_features

class HttpDownloadHandler(object):

    def __init__(self, settings):
        self.HTTPClientFactory = load_object(settings['DOWNLOADER_HTTPCLIENTFACTORY'])
        self.ClientContextFactory = load_object(settings['DOWNLOADER_CLIENTCONTEXTFACTORY'])

    def download_request(self, request, spider):
        """Return a deferred for the HTTP download"""
        factory = self.HTTPClientFactory(request)
        self._connect(factory)
        return factory.deferred

    def _connect(self, factory):
        host, port, scheme = factory.host, factory.port, factory.scheme
        if scheme == 'https':
            contextfactory = ClientContextFactory()
            return reactor.connectSSL(host, port, factory, contextfactory)
        else:
            return reactor.connectTCP(host, port, factory)

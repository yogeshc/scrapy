from scrapy import optional_features
from scrapy.exceptions import NotSupported


if 'ssl' in optional_features:
    from twisted.internet.ssl import ClientContextFactory
    from OpenSSL import SSL

    class ScrapyClientContextFactory(ClientContextFactory):
        "A SSL context factory which is more permissive against SSL bugs."
        # see https://github.com/scrapy/scrapy/issues/82
        # and https://github.com/scrapy/scrapy/issues/26

        def getContext(self, hostname=None, port=None):
            ctx = ClientContextFactory.getContext(self)
            # Enable all workarounds to SSL bugs as documented by
            # http://www.openssl.org/docs/ssl/SSL_CTX_set_options.html
            ctx.set_options(SSL.OP_ALL)
            return ctx

else:
    class ScrapyClientContextFactory(object):
        "Place holder SSL context factory for system without ssl support"

        def getContext(self, hostname=None, port=None):
            raise NotSupported("SSL support unavailable, "
                    "install pyopenssl library or python-openssl package")


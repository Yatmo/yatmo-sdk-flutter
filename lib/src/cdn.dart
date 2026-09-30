import 'configuration.dart';

/// POI icons are served from one CDN endpoint per country (same list as the web plugin's getCdnUrl).
class YatmoCdn {
  YatmoCdn._();

  static const Map<Country, String> _hosts = {
    Country.be: 'https://beprod-chh6e6e9hhg8bwha.z01.azurefd.net/',
    Country.fr: 'https://frprod-atf6hrhkezbhdqem.z01.azurefd.net/',
    Country.nl: 'https://nlprod-euexhcaedwekb9g9.z01.azurefd.net/',
    Country.lu: 'https://luprod-d3azhthcdgc5d7e2.z01.azurefd.net/',
    Country.ch: 'https://chprod-ebercaa7bddnbvbz.z01.azurefd.net/',
    Country.de: 'https://deprod.azureedge.net/',
    Country.it: 'https://itprod2.azureedge.net/',
    Country.es: 'https://esprod.azureedge.net/',
    Country.pt: 'https://ptprod.azureedge.net/',
    Country.ie: 'https://ieprod.azureedge.net/',
    Country.uk: 'https://ukprod.azureedge.net/',
    Country.at: 'https://atprod.azureedge.net/',
    Country.ca: 'https://caprod-hba9fuctcmdqcfea.z01.azurefd.net/',
    Country.gr: 'https://yatmogrprod-egf4hqdje7a8f4hd.z01.azurefd.net/',
    Country.ma: 'https://yatmomaprod-ecesacfgcmc3dugj.z01.azurefd.net/',
    Country.hr: 'https://yatmohrprod-aebpfxd3crhcfeh6.z01.azurefd.net/',
    Country.mt: 'https://yatmomtprod-bveegpf9csapdcdp.z01.azurefd.net/',
    Country.si: 'https://yatmosiprod-cxftg7d7g5bua8hv.z01.azurefd.net/',
    Country.rs: 'https://yatmorsprod-cdguargcaqcxhcgg.z01.azurefd.net/',
    Country.cy: 'https://yatmocyprod-bkg4g7f2b6hwahav.z01.azurefd.net/',
    Country.ba: 'https://yatmobaprod-d8duf5bffkdvg5b0.z01.azurefd.net/',
    Country.me: 'https://yatmomeprod-eafne6d5g3g0h3g2.z01.azurefd.net/',
    Country.bg: 'https://yatmobgprod-dqbzcte0aeg3c2b7.z01.azurefd.net/',
    Country.al: 'https://yatmoalprod-b4cpebdzd2cnerfu.z01.azurefd.net/',
    Country.au: 'https://yatmoauprod-g5gfbkbjhhduewdk.z01.azurefd.net/',
  };

  static String baseUrl(Country country) => _hosts[country] ?? _hosts[Country.be]!;

  /// `{cdn}/icons{size}/{iconId}@2x.png`, size 24 or 32.
  static String iconUrl(Country country, String iconId, {int size = 24}) => '${baseUrl(country)}icons$size/$iconId@2x.png';

  /// `{cdn}/subicons24/{subIconId}@2x.png`: transit line badges.
  static String subIconUrl(Country country, String subIconId) => '${baseUrl(country)}subicons24/$subIconId@2x.png';
}

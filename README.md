# infoaria

A partire dal file di configurazione InfoAria-centraline.yml viene generato il file D_output.xml eseguendo lo script D_test.pl. I percorsi di questi file si trovano all'interno del file D.pm nelle variabili:

my $CONFIG_CENTRALINE_FILE = 'InfoAria-Centraline.yml';
my $D_FILE_NAME = "D_output.xml";

All'interno del file D_test.pl va modificato l'anno:

InfoAria::D::generaXml(2018);

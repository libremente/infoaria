#====================================================================================
# InfoAria Arpa Puglia: Script per generazione dataset InfoAria
#====================================================================================
#
#   Copyright (C) 2018 Nicola Inchingolo
#
#   This file is part of InfoAria Arpa Puglia.
#
#   InfoAria Arpa Puglia is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   InfoAria Arpa Puglia is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Nome-Programma.  If not, see <http://www.gnu.org/licenses/>.
#
#====================================================================================
# Author: Nicola Inchingolo (n.inchingolo@arpa.puglia.it)
# Email: n.inchingolo (at sign) arpa.puglia.it
# License: GPLv3 (see LICENSE)
#====================================================================================

use strict;
use warnings;

use Net::FTP;

package InfoAria::Util;

sub normalizzaIdPerXml {
	my $id = shift;
	$id =~ s/:/_/g;
	return $id;
}

sub filtraStazioniORetiPerAnno {
	my $stazioni = shift;
	my $anno = shift;
	
	my $stazioni_filtrate = {};
	
	foreach my $id_stazione (keys %$stazioni) {
		my $stazione = $stazioni->{$id_stazione};
			
		if (isAnnoInIntervallo({anno => $anno, data_inizio => $stazione->{data_inizio}, data_fine => $stazione->{data_fine}})) {
			$stazioni_filtrate->{$id_stazione} = $stazioni->{$id_stazione};	
		}
	}
	
	return $stazioni_filtrate;
}

sub filtraInquinantiStazionePerAnno {
	my $inquinanti_stazione = shift;
	my $anno = shift;
	
	# inquinanti: [ {id: 6, nome: PM10, inizio: 2005-03-01, fine: 2017-11-30}, ..... ]
	
	my $inquinanti_filtrati = [];
	
	foreach my $inquinante (@$inquinanti_stazione) {
		my $data_inizio = $inquinante->{inizio};
		my $data_fine = '';
		
		if (defined $inquinante->{fine}) {
			$data_fine = $inquinante->{fine}; # la data fine e' opzionale
		}
		
		if (isAnnoInIntervallo({anno => $anno, data_inizio => $data_inizio, data_fine => $data_fine})) {
			push @$inquinanti_filtrati, $inquinante;
		}
	}
	
	return $inquinanti_filtrati;
}

sub isAnnoInIntervallo {
	my $params = shift;
	my $anno = $params->{anno}; # 2017
	my $data_inizio = $params->{data_inizio}; # 2016-01-01
	my $data_fine = $params->{data_fine}; # 2018-01-01
	my $anno_inizio = substr $data_inizio, 0, 4;

	my $annoInIntervallo = 0;
	
	if (!$data_fine) {
		# DATA FINE NON DEFINITA
		# devo controllare che l'anno della data inizio sia <= all'anno dato come parametro
		if ($anno_inizio <= $anno) {
			$annoInIntervallo = 1;
		}
	} else {
		# DATA FINE DEFINITA
		my $anno_fine = substr $data_fine, 0, 4;
		
		if ($anno_inizio <= $anno && $anno <= $anno_fine) {
			$annoInIntervallo = 1;
		}
	}
	return $annoInIntervallo;
}

# Il metodo restutuisce un hashref con queste chiavi:
# codice_project, nome, data_inizio, data_fine
# codice_ispra, metodo_misura, stima_incertezza
# isGiornaliero, isBiorario, isOrario
sub normalizzaInquinanteCentralina {
	my $params = shift;
	my $cfg = $params->{configurazione};
	my $inquinante = $params->{inquinante}; #{id: 8, nome: PM10, inizio: 2017-11-30, fine: 2018-11-30, frequenza: biorario, eq: SA} 
	# [ 10, 'Benzene', '2015-03-16' ] oppure per PM10 orario [ 5, 'PM10/o', '2015-03-16' ] 
	
	my $inqRet; # per il return
	
	my $id_inq_prj = $inquinante->{id};
	my $nome_inq = $inquinante->{nome};
	my $data_inizio = $inquinante->{inizio};
	my $data_fine = "";
	my $demonstration_report_id = "";
	
	if (defined $inquinante->{fine}) {
		$data_fine = $inquinante->{fine}; # la data fine e' opzionale
	}
	if (defined $inquinante->{eq}) {
		$demonstration_report_id = $inquinante->{eq}; # il demonstration report e' opzionale
	}
	
	my $anagrafica_inquinante = $cfg->{inquinanti}->{$nome_inq};
	
	$inqRet = {
		codice_project => $id_inq_prj,
		nome => $nome_inq,
		data_inizio => $data_inizio,
		data_fine => $data_fine,
		codice_ispra => $anagrafica_inquinante->{codice_ispra},
		tipo_misura => $anagrafica_inquinante->{tipo_misura}, # automatic / active
		metodo_misura => $anagrafica_inquinante->{metodo_misura}, # automatic
		stima_incertezza => $anagrafica_inquinante->{stima_incertezza},
		tecnica_analitica => $anagrafica_inquinante->{tecnica_analitica}, # active
		metodo_campionamento => $anagrafica_inquinante->{metodo_campionamento}, # active
		demonstration_report_id => $demonstration_report_id,
		is_giornaliero => 0, is_biorario => 0, is_orario => 1
	};
	
	# PM10, PM2.5: isGiornaliero, isBiorario, isOrario
	if ($nome_inq eq "PM10" || $nome_inq eq "PM2.5") { # e' PM10 o  PM2.5
		if (defined $inquinante->{frequenza}) { #caso PM10/o PM10/b PM2.5/o PM2.5/b  
			if ($inquinante->{frequenza} eq "biorario") {
				$inqRet->{is_biorario} = 1;
				$inqRet->{is_orario} = 0;
			}
		} else { #caso PM10 PM2.5
			$inqRet->{is_giornaliero} = 1;
			$inqRet->{is_biorario} = 0;
			$inqRet->{is_orario} = 0;
		}	
	}
	
	return $inqRet;
}

# IT2019A_10_IR-GFC_2011-02-08_00_00_00
sub creaIdSamplingPoint {
	my $params = shift;
	my $stazione = $params->{stazione};
	my $inquinante = $params->{inquinante};
	
	my $sppId;
	
	if ($inquinante->{tipo_misura} eq 'active') {
		$sppId = sprintf('%s_%s_%s_%s_00:00:00', $stazione->{id_stazione}, $inquinante->{codice_ispra}, $inquinante->{tecnica_analitica}, $inquinante->{data_inizio});
	} else {
		$sppId = sprintf('%s_%s_%s_%s_00:00:00', $stazione->{id_stazione}, $inquinante->{codice_ispra}, $inquinante->{metodo_misura}, $inquinante->{data_inizio});
	}
	
	return $sppId
}

#<aqd:content xlink:href="SPP.IT.PUGLIA_7_UV-P_REF"/>
sub creaIdSamplingPointProcess {
	my $params = shift;
	my $inquinante = $params->{inquinante};
	my $demonstration_report_id = $params->{demonstration_report_id};
	my $frequenza_campionamento = $params->{frequenza_campionamento};
		
	my $id_inquinante = $inquinante->{codice_ispra};
	my $metodo_misura = $inquinante->{metodo_misura};
	my $stima_incertezza = $inquinante->{stima_incertezza};

	my $sppId = "SPP.IT.PUGLIA_${id_inquinante}_";
	
	if ($inquinante->{tipo_misura} eq 'active') {
		$sppId = $sppId . $inquinante->{tecnica_analitica};
	} else {
		$sppId = $sppId . $inquinante->{metodo_misura};
	}
	
	if (!$demonstration_report_id) {
		$sppId = $sppId . "_REF";
	} else {	
		$sppId = $sppId . "_" . $demonstration_report_id;
	}
	
	$sppId = sprintf("%s_%s_%s_%s_%s", $sppId,
		$frequenza_campionamento->{duration_num_units}, $frequenza_campionamento->{duration_unit},
		$frequenza_campionamento->{cadence_num_units}, $frequenza_campionamento->{cadence_unit}
	);
	
	return $sppId
}

sub inviaFileViaFtpAIspra {
	my $params = shift;
	my $config = $params->{config};
	my $local_file = $params->{local_file};
	my $remote_file = $params->{remote_file};
	
	my $f = Net::FTP->new($config->{ftp}->{host}, Passive => 1);
	$f->login($config->{ftp}->{user}, $config->{ftp}->{password});
	$f->cwd("files");
	$f->binary();
	$f->put($local_file, $remote_file);
	$f->quit();	
}

1;
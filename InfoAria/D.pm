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

use YAML;
use XML::Writer;

package InfoAria::D;

use InfoAria::Util;

my $CONFIG_CENTRALINE_FILE = 'InfoAria-Centraline.yml';
my $D_FILE_NAME = "D_output.xml";
my $MIDNIGHT_TIME_SUFFIX = 'T00:00:00+01:00';

my %NS = ( # pfx => uri
	'ad'    => 'urn:x-inspire:specification:gmlas:Addresses:3.0',
	'am'    => 'http://inspire.ec.europa.eu/schemas/am/3.0',
    'aqd'   => 'http://dd.eionet.europa.eu/schemaset/id2011850eu-1.0',
    'base'  => 'http://inspire.ec.europa.eu/schemas/base/3.3',
    'base2' => 'http://inspire.ec.europa.eu/schemas/base2/1.0',
    'ef'    => 'http://inspire.ec.europa.eu/schemas/ef/3.0',
    'gco'   => 'http://www.isotc211.org/2005/gco',
    'gmd'   => 'http://www.isotc211.org/2005/gmd',
    'gml'   => 'http://www.opengis.net/gml/3.2',
    'gn'    => 'urn:x-inspire:specification:gmlas:GeographicalNames:3.0',
    'om'    => 'http://www.opengis.net/om/2.0',
    'ompr'  => 'http://inspire.ec.europa.eu/schemas/ompr/2.0',
    'sam'   => 'http://www.opengis.net/sampling/2.0',
    'sams'  => 'http://www.opengis.net/samplingSpatial/2.0',
    'swe'   => 'http://www.opengis.net/swe/2.0',
    'xlink' => 'http://www.w3.org/1999/xlink',
    'xsi'   => 'http://www.w3.org/2001/XMLSchema-instance'
);

my @SCHEMA_LOCATIONS = (
 'http://dd.eionet.europa.eu/schemaset/id2011850eu-1.0 http://dd.eionet.europa.eu/schemas/id2011850eu-1.0/AirQualityReporting.xsd',
 'http://www.opengis.net/gml/3.2 http://schemas.opengis.net/gml/3.2.1/gml.xsd' # senza questo la validazione da errore cvc-elt.1: impossibile trovare la dichiarazione dell'elemento "gml:FeatureCollection". 
);

sub generaXml {
	my $anno = shift;
	
	# Open the config
	my $config_centraline = YAML::LoadFile( $CONFIG_CENTRALINE_FILE );
	
	my $_D;
	open $_D, '>', $D_FILE_NAME;
	
	my $NS_PREFIX_MAP = {}; # uri => pfx
	foreach my $pfx (keys %NS) {
	    $NS_PREFIX_MAP->{$NS{$pfx}} = $pfx;
	}
	
	my $w = new XML::Writer(
		OUTPUT => $_D,
		NAMESPACES => 1,
		DATA_MODE => 1,
		UNSAFE => 1,
		DATA_INDENT => 3,
		PREFIX_MAP => $NS_PREFIX_MAP,
		FORCED_NS_DECLS => [values %NS]
	);
	
	#### XML ROOT NODE [gml:FeatureCollection]
	$w->raw('<?xml version="1.0" encoding="UTF-8"?>'. "\n"); # $w->xmlDecl("UTF-8"); con xmlDecl mi mette una riga vuota
	$w->startTag([$NS{gml}, 'FeatureCollection'], [$NS{gml}, 'id'] => 'IT_AQD', [$NS{xsi}, 'schemaLocation'] => "$SCHEMA_LOCATIONS[0] $SCHEMA_LOCATIONS[1]" );
	
		#### REPORTING HEADER
		$w->startTag([$NS{gml}, 'featureMember']);
		
			$w->startTag([$NS{aqd}, 'AQD_ReportingHeader'], [$NS{gml}, 'id'] => 'D_ReportingHeader');
			
				$w->dataElement([$NS{aqd}, 'change'], 'true');
				$w->dataElement([$NS{aqd}, 'changeDescription'], "--------$anno submissions-----");
				
				# inspireId
				writeInspireId({xml_writer => $w, ns => \%NS, inspireIdNs => 'aqd' , localId => 'IT_DatasetD', namespace => 'IT.ISPRA.AQD', versionId => "D Dataset IT PUGLIA $anno"});
			
				$w->startTag([$NS{aqd}, 'reportingAuthority']);
					writeRelatedParty({xml_writer => $w, ns => \%NS });
				$w->endTag(); #aqd:reportingAuthority
				
				$w->startTag([$NS{aqd}, 'reportingPeriod']);
					$w->startTag([$NS{gml}, 'TimePeriod'], [$NS{'gml'}, 'id'] => 'ReportingTimePeriod_ReportingHeader');
						$w->dataElement([$NS{gml}, 'beginPosition'], "$anno-01-01T00:00:01+01:00");
						$w->dataElement([$NS{gml}, 'endPosition'], "$anno-12-31T24:00:00+01:00");
					$w->endTag(); #gml:TimePeriod
				$w->endTag(); #aqd:reportingPeriod
					
				#RETI
				#<aqd:content xlink:href="IT.ISPRA.AQD/NET.IT082A"/>
				my $reti = $config_centraline->{reti};
				$reti = InfoAria::Util::filtraStazioniORetiPerAnno($reti, $anno);
				foreach my $id_rete (keys %$reti) {
					$w->emptyTag([$NS{aqd}, 'content'], [$NS{'xlink'}, 'href'] => "IT.ISPRA.AQD/NET.$id_rete");					
				}
	
				#STAZIONI
				#<aqd:content xlink:href="IT.ISPRA.AQD/STA.IT0187A"/>
				my $stazioni = $config_centraline->{stazioni};
				$stazioni = InfoAria::Util::filtraStazioniORetiPerAnno($stazioni, $anno);
				foreach my $id_stazione (keys %$stazioni) {
					$w->emptyTag([$NS{aqd}, 'content'], [$NS{'xlink'}, 'href'] => "IT.ISPRA.AQD/STA.$id_stazione");					
				}
							
				#SPO
				#<aqd:content xlink:href="IT.ISPRA.AQD/SPO.IT0063A_5_BETA_2000-05-05_00:00:00"/>
				foreach my $id_stazione (keys %$stazioni) {
					my $stazione = $stazioni->{$id_stazione};
					$stazione->{id_stazione} = $id_stazione;
					my $inquinanti = $stazioni->{$id_stazione}->{inquinanti};
					$inquinanti = InfoAria::Util::filtraInquinantiStazionePerAnno($inquinanti, $anno);
					
					foreach my $inquinante (@$inquinanti) {
						my $inq = InfoAria::Util::normalizzaInquinanteCentralina({configurazione => $config_centraline, inquinante => $inquinante});
						
						my $id_spo = InfoAria::Util::creaIdSamplingPoint({stazione => $stazioni->{$id_stazione}, inquinante => $inq});
						
						$w->emptyTag([$NS{aqd}, 'content'], [$NS{'xlink'}, 'href'] => "IT.ISPRA.AQD/SPO.$id_spo");
					}
				}
				
				#SPP
				#<aqd:content xlink:href="IT.ISPRA.AQD/SPP.IT.PUGLIA_7_UV-P_REF"/>
				my $sppCatalog = {}; # questo mi serve per non inserire due volte lo stesso spp
				my $inquinanti = $config_centraline->{inquinanti};
				foreach my $nome_inquinante (keys %$inquinanti) {
					my $inquinante = $inquinanti->{$nome_inquinante};
					my $demonstration_reports = $inquinante->{demonstration_reports};
			
					if (!$demonstration_reports) {
						$demonstration_reports = [ 0 ];
					}
	
					my $frequenze_campionamento = generaFrequenzeCampionamento($nome_inquinante);
					
					foreach my $frequenza_campionamento (@$frequenze_campionamento) {
						foreach my $demonstration_report_id (@$demonstration_reports) {
							my $idSpp = InfoAria::Util::creaIdSamplingPointProcess({
								inquinante => $inquinante,
								demonstration_report_id => $demonstration_report_id,
								frequenza_campionamento => $frequenza_campionamento
							});
							
							unless (defined $sppCatalog->{$idSpp}) {
								$w->emptyTag([$NS{aqd}, 'content'], [$NS{'xlink'}, 'href'] => "IT.ISPRA.AQD/" . $idSpp);
								$sppCatalog->{$idSpp} = 1;
							}
							
						}
					}
				}
			
				#LEGAME SPO ad SPP e SAM
				#<ef:procedure xlink:href="IT.ISPRA.AQD/SPP.IT0063A_5029_GC-MS_2014-01-01_00:00:00"/>
				#<ef:featureOfInterest xlink:href="IT.ISPRA.AQD/SAM.IT0063A_5029_GC-MS_2014-01-01_00:00:00"/>
			$w->endTag(); #AQD_ReportingHeader
		$w->endTag(); #gml:featureMember
		
		####  Networks [AQD_Network]
		foreach my $id_rete (keys %$reti) {
			my $rete = $reti->{$id_rete};
			 
			$w->startTag([$NS{gml}, 'featureMember']);
				$w->startTag([$NS{aqd}, 'AQD_Network'], [$NS{gml}, 'id'] => "NET.$id_rete");
				
					writeInspireId({xml_writer => $w, ns => \%NS, inspireIdNs => 'ef', localId => "NET.$id_rete", namespace => 'IT.ISPRA.AQD', versionId => $rete->{data_inizio} . " 00:00:00.000000"});
					
					$w->dataElement([$NS{ef}, 'name'], $rete->{nome});
					$w->emptyTag([$NS{ef}, 'mediaMonitored'], [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/MediaValue/air');
					
					$w->startTag([$NS{ef}, 'responsibleParty']);
						writeRelatedParty({xml_writer => $w, ns => \%NS });
					$w->endTag(); #ef:responsibleParty
	
					$w->emptyTag([$NS{ef}, 'organisationLevel'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/organisationallevel/national');
					$w->emptyTag([$NS{aqd}, 'networkType'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/networktype/'. $rete->{tipo});
					
					$w->startTag([$NS{aqd}, 'operationActivityPeriod']);
						$w->startTag([$NS{gml}, 'TimePeriod'], [$NS{'gml'}, 'id'] => 'TimePeriod_'. $id_rete);
							$w->dataElement([$NS{gml}, 'beginPosition'], $rete->{data_inizio} . $MIDNIGHT_TIME_SUFFIX);
							$w->emptyTag([$NS{gml}, 'endPosition'], indeterminatePosition => 'unknown');
						$w->endTag(); #gml:TimePeriod
					$w->endTag(); #aqd:operationActivityPeriod
					
					$w->emptyTag([$NS{aqd}, 'aggregationTimeZone'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/timezone/UTC+01');
				$w->endTag(); #aqd:AQD_Network
			$w->endTag(); #gml:featureMember	
		}
				
		####  Stations [AQD_Station]
		foreach my $id_stazione (keys %$stazioni) {
			my $stazione = $stazioni->{$id_stazione};
			
			$w->startTag([$NS{gml}, 'featureMember']);
				$w->startTag([$NS{aqd}, 'AQD_Station'], [$NS{gml}, 'id'] => "STA.$id_stazione");
					
					writeInspireId({xml_writer => $w, ns => \%NS, inspireIdNs => 'ef', localId => "STA.$id_stazione", namespace => 'IT.ISPRA.AQD', versionId => $stazione->{data_inizio} . " 00:00:00.000000"});
					
					$w->dataElement([$NS{ef}, 'name'], $stazione->{nome});
					$w->emptyTag([$NS{ef}, 'mediaMonitored'], [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/MediaValue/air');
					
					$w->startTag([$NS{ef}, 'geometry']);
						writePoint({xml_writer => $w, ns => \%NS, id => $id_stazione, coordinate => $stazione->{coordinate}});
					$w->endTag(); #ef:geometry
	
					$w->emptyTag([$NS{ef}, 'measurementRegime'], [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/MeasurementRegimeValue/continuousDataCollection');
					$w->dataElement([$NS{ef}, 'mobile'], 'false');
					
					$w->startTag([$NS{ef}, 'operationalActivityPeriod']);
						$w->startTag([$NS{ef}, 'OperationalActivityPeriod'], [$NS{gml}, 'id'] => "STA.OA.$id_stazione");
							$w->startTag([$NS{ef}, 'activityTime']);
								$w->startTag([$NS{gml}, 'TimePeriod'], [$NS{'gml'}, 'id'] => 'TimePeriod_'. $id_stazione);
									$w->dataElement([$NS{gml}, 'beginPosition'], $stazione->{data_inizio} . $MIDNIGHT_TIME_SUFFIX);
									$w->emptyTag([$NS{gml}, 'endPosition'], indeterminatePosition => 'unknown');
								$w->endTag(); #gml:TimePeriod
							$w->endTag(); #ef:activityTime
						$w->endTag(); #ef:OperationalActivityPeriod
					$w->endTag(); #ef:operationalActivityPeriod
					
					$w->emptyTag([$NS{ef}, 'belongsTo'], [$NS{'xlink'}, 'href'] => 'IT.ISPRA.AQD/NET.'. $stazione->{id_rete});
					$w->dataElement([$NS{aqd}, 'natlStationCode'], $stazione->{id_stazione_n});
					$w->dataElement([$NS{aqd}, 'municipality'], $stazione->{indirizzo});
					$w->dataElement([$NS{aqd}, 'EUStationCode'], $id_stazione);
					$w->emptyTag([$NS{aqd}, 'areaClassification'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/areaclassification/' .  $stazione->{tipo_area});
					
					if ($stazione->{tipo_stazione} eq 'traffic') {
						$w->startTag([$NS{aqd}, 'dispersionSituation']);
							$w->startTag([$NS{aqd}, 'DispersionSituation']);
								$w->dataElement([$NS{aqd}, 'distanceJunction'], $stazione->{distanceJunction}, uom => 'm');
								$w->dataElement([$NS{aqd}, 'trafficVolume'], $stazione->{trafficVolume});
								$w->dataElement([$NS{aqd}, 'heavy-dutyFraction'], $stazione->{'heavy-dutyFraction'});
								$w->dataElement([$NS{aqd}, 'trafficSpeed'], $stazione->{trafficSpeed}, uom => 'km/h');
								$w->dataElement([$NS{aqd}, 'streetWidth'], $stazione->{streetWidth}, uom => 'm');
								$w->dataElement([$NS{aqd}, 'heightFacades'], $stazione->{heightFacades}, uom => 'm');
							$w->endTag(); #aqd:DispersionSituation
						$w->endTag(); #aqd:dispersionSituation
					} else {
						$w->startTag([$NS{aqd}, 'dispersionSituation']);
							$w->emptyTag([$NS{aqd}, 'DispersionSituation']);
						$w->endTag(); #aqd:dispersionSituation
					}
					
					$w->dataElement([$NS{aqd}, 'altitude'], $stazione->{altitudine}, uom => 'm');
					
				$w->endTag(); #aqd:AQD_Station
			$w->endTag(); #gml:featureMember
		}
		
		#AQD_SamplingPoint
		foreach my $id_stazione (keys %$stazioni) {
			my $stazione = $stazioni->{$id_stazione};
			$stazione->{id_stazione} = $id_stazione;
			my $inquinanti = $stazione->{inquinanti};
			$inquinanti = InfoAria::Util::filtraInquinantiStazionePerAnno($inquinanti, $anno);
			
			foreach my $inquinante (@$inquinanti) {
				my $inq = InfoAria::Util::normalizzaInquinanteCentralina({configurazione => $config_centraline, inquinante => $inquinante});
				my $id_spo = InfoAria::Util::creaIdSamplingPoint({stazione => $stazione, inquinante => $inq});
				
				my $frequenza_campionamento = calcolaFrequenzaCampionamento($inq);
				
				#inserisco l'spp con il demonstration report di riferimento
				my $id_spp = InfoAria::Util::creaIdSamplingPointProcess({
					inquinante => $inq,
					demonstration_report_id => $inq->{demonstration_report_id},
					frequenza_campionamento => $frequenza_campionamento
				});
				
				$w->startTag([$NS{gml}, 'featureMember']);
					$w->startTag([$NS{aqd}, 'AQD_SamplingPoint'], [$NS{gml}, 'id'] => InfoAria::Util::normalizzaIdPerXml("SPO.$id_spo"));
					
						writeInspireId({xml_writer => $w, ns => \%NS, inspireIdNs => 'ef', localId => "SPO.$id_spo", namespace => 'IT.ISPRA.AQD', versionId => $inq->{data_inizio} . " 00:00:00.000000"});
						$w->dataElement([$NS{ef}, 'name'], $id_spo);
						$w->emptyTag([$NS{ef}, 'mediaMonitored'], [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/MediaValue/air');
						$w->startTag([$NS{ef}, 'geometry']);
							writePoint({xml_writer => $w, ns => \%NS, id => $id_spo, coordinate => $stazione->{coordinate}});
						$w->endTag(); #ef:geometry
					
						#<ef:ObservingCapability gml:id="SPO.OC.IT1818A_5_BETA_2009-07-01_00_00_00">
						#<gml:TimePeriod gml:id="SPO.OC.TP.IT1818A_5_BETA_2009-07-01_00_00_00">
						$w->startTag([$NS{ef}, 'observingCapability']);
							$w->startTag([$NS{ef}, 'ObservingCapability'], [$NS{'gml'}, 'id'] => InfoAria::Util::normalizzaIdPerXml('SPO.OC.'. $id_spo));
								$w->startTag([$NS{ef}, 'observingTime']);
									$w->startTag([$NS{gml}, 'TimePeriod'], [$NS{'gml'}, 'id'] => InfoAria::Util::normalizzaIdPerXml('SPO.OC.TP.'. $id_spo));
										$w->dataElement([$NS{gml}, 'beginPosition'], $inq->{data_inizio} . $MIDNIGHT_TIME_SUFFIX);
										$w->emptyTag([$NS{gml}, 'endPosition'], indeterminatePosition => 'unknown');
									$w->endTag(); #gml:TimePeriod
								$w->endTag(); #ef:observingTime
			
								$w->emptyTag([$NS{ef}, 'processType'],       [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/ProcessTypeValue/process');
								$w->emptyTag([$NS{ef}, 'resultNature'],      [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/ResultNatureValue/primary');
								$w->emptyTag([$NS{ef}, 'procedure'],         [$NS{'xlink'}, 'href'] => 'IT.ISPRA.AQD/' . $id_spp);
								$w->emptyTag([$NS{ef}, 'featureOfInterest'], [$NS{'xlink'}, 'href'] => 'IT.ISPRA.AQD/SAM.' . $id_spo);
								$w->emptyTag([$NS{ef}, 'observedProperty'],  [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/pollutant/' . $inq->{codice_ispra} );
								
							$w->endTag(); #ef:ObservingCapability
						$w->endTag(); #ef:observingCapability
						
						$w->emptyTag([$NS{ef}, 'broader'], [$NS{'xlink'}, 'href'] => 'IT.ISPRA.AQD/STA.' . $id_stazione);
						$w->emptyTag([$NS{ef}, 'measurementRegime'], [$NS{'xlink'}, 'href'] => 'http://inspire.ec.europa.eu/codeList/MeasurementRegimeValue/continuousDataCollection');
						$w->dataElement([$NS{ef}, 'mobile'], 'false');
						
						$w->startTag([$NS{ef}, 'operationalActivityPeriod']);
							$w->startTag([$NS{ef}, 'OperationalActivityPeriod'], [$NS{'gml'}, 'id'] => InfoAria::Util::normalizzaIdPerXml('SPO.OP.'. $id_spo));
								$w->startTag([$NS{ef}, 'activityTime']);
									$w->startTag([$NS{gml}, 'TimePeriod'], [$NS{'gml'}, 'id'] => InfoAria::Util::normalizzaIdPerXml('SPO.OP.TP.'. $id_spo));
										$w->dataElement([$NS{gml}, 'beginPosition'], $inq->{data_inizio} . $MIDNIGHT_TIME_SUFFIX);
										$w->emptyTag([$NS{gml}, 'endPosition'], indeterminatePosition => 'unknown');
									$w->endTag(); #gml:TimePeriod
								$w->endTag(); #ef:activityTime
							$w->endTag(); #ef:OperationalActivityPeriod
						$w->endTag(); #ef:operationalActivityPeriod
					
						$w->emptyTag([$NS{ef}, 'belongsTo'], [$NS{'xlink'}, 'href'] => 'IT.ISPRA.AQD/NET.' . $stazione->{id_rete});
						$w->emptyTag([$NS{aqd}, 'assessmentType'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/assessmenttype/fixed');
	
						$w->startTag([$NS{aqd}, 'relevantEmissions']);
							$w->startTag([$NS{aqd}, 'RelevantEmissions']);
								# solo per stazioni di tipo industrial
								if ($stazione->{tipo_stazione} eq 'industrial') {
									$w->dataElement([$NS{aqd}, 'distanceSource'], $stazione->{distanceSource}, uom => 'm');
									$w->dataElement([$NS{aqd}, 'industrialEmissions'], $stazione->{industrialEmissions}, uom => 't/year');
								}
								$w->emptyTag([$NS{aqd}, 'stationClassification'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/stationclassification/' . $stazione->{tipo_stazione});
							$w->endTag(); #aqd:RelevantEmissions
						$w->endTag(); #aqd:relevantEmissions
						$w->dataElement([$NS{aqd}, 'usedAQD'], 'true');
						$w->emptyTag([$NS{aqd}, 'reportingDB'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/reportinglevel/national');
					
					$w->endTag(); #aqd:AQD_AQD_SamplingPoint
				$w->endTag(); #gml:featureMember
			}
		}
		
		#AQD_SamplingPointProcess
		#<aqd:content xlink:href="IT.ISPRA.AQD/SPP.IT.PUGLIA_7_UV-P_REF"/>
		$sppCatalog = {}; # questo mi serve per non inserire due volte lo stesso spp
		foreach my $nome_inquinante (keys %$inquinanti) {
			my $inquinante = $inquinanti->{$nome_inquinante};
			my $demonstration_reports = $inquinante->{demonstration_reports};
			
			if (!$demonstration_reports) {
				$demonstration_reports = [ 0 ];
			}
			
			my $frequenze_campionamento = generaFrequenzeCampionamento($nome_inquinante);
			
			foreach my $frequenza_campionamento (@$frequenze_campionamento) {
				foreach my $demonstration_report_id (@$demonstration_reports) {
					
					my $id_spp = InfoAria::Util::creaIdSamplingPointProcess({
						inquinante => $inquinante,
						demonstration_report_id => $demonstration_report_id,
						frequenza_campionamento => $frequenza_campionamento
					});
					
					unless (defined $sppCatalog->{$id_spp}) {
						$w->startTag([$NS{gml}, 'featureMember']);
							$w->startTag([$NS{aqd}, 'AQD_SamplingPointProcess'], [$NS{gml}, 'id'] => InfoAria::Util::normalizzaIdPerXml($id_spp));
						
							writeInspireId({xml_writer => $w, ns => \%NS, inspireIdNs => 'ompr', localId => $id_spp, namespace => 'IT.ISPRA.AQD', versionId => "2010-01-11 00:00:00.000000"});
							$w->dataElement([$NS{ompr}, 'type'], 'Ambient air quality measurement instrument configuration');
						
							$w->startTag([$NS{ompr}, 'responsibleParty']);
								writeRelatedParty({xml_writer => $w, ns => \%NS });
							$w->endTag(); #ompr:responsibleParty
							
							# tipo_misura: automatic / active (metalli)
							$w->emptyTag([$NS{aqd}, 'measurementType'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/measurementtype/' . $inquinante->{tipo_misura});
							
							if ($inquinante->{tipo_misura} eq 'automatic') {
								$w->startTag([$NS{aqd}, 'measurementMethod']);
									$w->startTag([$NS{aqd}, 'MeasurementMethod']);
										$w->emptyTag([$NS{aqd}, 'measurementMethod'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/measurementmethod/' . $inquinante->{metodo_misura});
									$w->endTag(); #aqd:MeasurementMethod
								$w->endTag(); #aqd:measurementMethod
							} else {
								# metalli
								$w->startTag([$NS{aqd}, 'samplingMethod']);
									$w->startTag([$NS{aqd}, 'SamplingMethod']);
										$w->emptyTag([$NS{aqd}, 'samplingMethod'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/samplingmethod/' . $inquinante->{metodo_campionamento});
									$w->endTag(); #aqd:SamplingMethod
								$w->endTag(); #aqd:samplingMethod
								$w->startTag([$NS{aqd}, 'analyticalTechnique']);
									$w->startTag([$NS{aqd}, 'AnalyticalTechnique']);
										$w->emptyTag([$NS{aqd}, 'analyticalTechnique'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/analyticaltechnique/' . $inquinante->{tecnica_analitica});
									$w->endTag(); #aqd:AnalyticalTechnique
								$w->endTag(); #aqd:analyticalTechnique
							}
							
							#<aqd:equivalenceDemonstration>
							$w->startTag([$NS{aqd}, 'equivalenceDemonstration']);
								$w->startTag([$NS{aqd}, 'EquivalenceDemonstration']);
									if ($demonstration_report_id) {
										$w->emptyTag([$NS{aqd}, 'equivalenceDemonstrated'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/equivalencedemonstrated/yes');
										$w->dataElement([$NS{aqd}, 'demonstrationReport'], $config_centraline->{demonstration_reports}->{$demonstration_report_id});
									} else {
										$w->emptyTag([$NS{aqd}, 'equivalenceDemonstrated'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/aq/equivalencedemonstrated/ref');
										$w->emptyTag([$NS{aqd}, 'demonstrationReport']);
									}
								$w->endTag(); #aqd:EquivalenceDemonstration
							$w->endTag(); #aqd:equivalenceDemonstration
							
							#<aqd:dataQuality>
							$w->startTag([$NS{aqd}, 'dataQuality']);
								$w->startTag([$NS{aqd}, 'DataQuality']);
									$w->dataElement([$NS{aqd}, 'detectionLimit'], $inquinante->{data_quality}->{detection_limit}, 'uom' => 'http://dd.eionet.europa.eu/vocabulary/uom/concentration/' .  $inquinante->{data_quality}->{uom});
									$w->dataElement([$NS{aqd}, 'documentation'], , $inquinante->{data_quality}->{documentation});
									$w->dataElement([$NS{aqd}, 'qaReport'], $inquinante->{data_quality}->{qa_report});
								$w->endTag(); #aqd:DataQuality
							$w->endTag(); #aqd:dataQuality
							
							#<aqd:duration>
							#	<aqd:TimeReferences>
							#		<aqd:unit xlink:href="http://dd.eionet.europa.eu/vocabulary/uom/time/continuous"/>
							#		<aqd:numUnits>1</aqd:numUnits>
							$w->startTag([$NS{aqd}, 'duration']);
								$w->startTag([$NS{aqd}, 'TimeReferences']);
									$w->emptyTag([$NS{aqd}, 'unit'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/uom/time/' . $frequenza_campionamento->{duration_unit});
									$w->dataElement([$NS{aqd}, 'numUnits'], $frequenza_campionamento->{duration_num_units});
								$w->endTag(); #aqd:TimeReferences
							$w->endTag(); #aqd:duration
							
							#<aqd:cadence>
							#	<aqd:TimeReferences>
							#		<aqd:unit xlink:href="http://dd.eionet.europa.eu/vocabulary/uom/time/hour"/>
							#		<aqd:numUnits>1</aqd:numUnits>
							$w->startTag([$NS{aqd}, 'cadence']);
								$w->startTag([$NS{aqd}, 'TimeReferences']);
									$w->emptyTag([$NS{aqd}, 'unit'], [$NS{'xlink'}, 'href'] => 'http://dd.eionet.europa.eu/vocabulary/uom/time/' . $frequenza_campionamento->{cadence_unit});
									$w->dataElement([$NS{aqd}, 'numUnits'], $frequenza_campionamento->{cadence_num_units});
								$w->endTag(); #aqd:TimeReferences
							$w->endTag(); #aqd:cadence
							
							$w->endTag(); #aqd:AQD_SamplingPointProcess
						$w->endTag(); #gml:featureMember
	
						$sppCatalog->{$id_spp} = 1; #aggiungo l'id al catalogo
					} # unless defined sppCatalog->{$id_spp} non e' gia' presente (non inserisco 2 spp con lo stesso id)
				} #foreach demonstration report
			} #foreach frequenza campionamento
		} #foreach inquinante
		
		#AQD_Sample
		foreach my $id_stazione (keys %$stazioni) {
			my $stazione = $stazioni->{$id_stazione};
			$stazione->{id_stazione} = $id_stazione;
			my $inquinanti = $stazione->{inquinanti};
			$inquinanti = InfoAria::Util::filtraInquinantiStazionePerAnno($inquinanti, $anno);
			
			foreach my $inquinante (@$inquinanti) {
				my $inq = InfoAria::Util::normalizzaInquinanteCentralina({configurazione => $config_centraline, inquinante => $inquinante});
				my $id_spo = InfoAria::Util::creaIdSamplingPoint({stazione => $stazione, inquinante => $inq});
				
				$w->startTag([$NS{gml}, 'featureMember']);
					$w->startTag([$NS{aqd}, 'AQD_Sample'], [$NS{gml}, 'id'] => InfoAria::Util::normalizzaIdPerXml("SAM.$id_spo"));
						$w->emptyTag([$NS{sam}, 'sampledFeature'], 'nilReason' => 'unknown');
						$w->startTag([$NS{sams}, 'shape']);
							writePoint({xml_writer => $w, ns => \%NS, id => "SAM.$id_spo", coordinate => $stazione->{coordinate}});
						$w->endTag(); #sam:shape
						writeInspireId({xml_writer => $w, ns => \%NS, inspireIdNs => 'aqd', localId => "SAM.$id_spo", namespace => 'IT.ISPRA.AQD', versionId => $inq->{data_inizio} . " 00:00:00.000000"});
						
						#inlineHeight sempre uguale a 3.0
						$w->dataElement([$NS{aqd}, 'inletHeight'], '3.0', uom => 'http://dd.eionet.europa.eu/vocabulary/uom/length/m');
						
						#buildingDistance e kerbDistance solo per stazioni di tipo traffic
						if  ($stazione->{tipo_stazione} eq 'traffic') {
							$w->comment("traffic station");
							$w->dataElement([$NS{aqd}, 'buildingDistance'], $stazione->{buildingDistance}, uom => 'http://dd.eionet.europa.eu/vocabulary/uom/length/m'); #traffic only
							$w->dataElement([$NS{aqd}, 'kerbDistance'], $stazione->{kerbDistance}, uom => 'http://dd.eionet.europa.eu/vocabulary/uom/length/m'); #traffic only
						}
					$w->endTag(); #aqd:AQD_Sample
				$w->endTag(); #gml:featureMember
			}
		}
		
	
	$w->endTag(); #gml:FeatureCollection
	$w->end();
	
	close $_D;

}

sub writeInspireId {
	my $params = shift;
	my $w = $params->{xml_writer};
	my $NS = %{$params->{ns}};
	my $inspireIdNs = $params->{inspireIdNs};
	my $localId = $params->{localId};
	my $namespace = $params->{namespace};
	my $versionId = $params->{versionId};
	
	$w->startTag([$NS{$inspireIdNs}, 'inspireId']);
		$w->startTag([$NS{base}, 'Identifier']);
			$w->dataElement([$NS{base}, 'localId'], $localId);
			$w->dataElement([$NS{base}, 'namespace'], $namespace);
			if ($versionId) {
				$w->dataElement([$NS{base}, 'versionId'], $versionId);	
			}
		$w->endTag(); #base:Identifier
	$w->endTag(); # <<inspireIdNs>>:inspireId
}

sub writePoint {
	my $params = shift;
	my $w = $params->{xml_writer};
	my $NS = %{$params->{ns}};
	my $coordinate = $params->{coordinate};
	my $id = $params->{id};
	
	$w->startTag([$NS{gml}, 'Point'], [$NS{gml}, 'id'] => InfoAria::Util::normalizzaIdPerXml('PT_' . $id),  srsName => 'urn:ogc:def:crs:EPSG::4326');
		$w->dataElement([$NS{gml}, 'pos'], $coordinate, srsDimension => 2);
	$w->endTag(); #gml:Point
}

sub writeRelatedParty {
	my $params = shift;
	my $w = $params->{xml_writer};
	my $NS = %{$params->{ns}};
	
	$w->startTag([$NS{base2}, 'RelatedParty']);
	
		$w->startTag([$NS{base2}, 'individualName']);
			$w->startTag([$NS{gmd}, 'PT_FreeText']);
				$w->startTag([$NS{gmd}, 'textGroup']);
					$w->dataElement([$NS{gmd}, 'LocalisedCharacterString'], '<Nome> <Cognome>');
				$w->endTag(); #gmd:textGroup
			$w->endTag(); #gmd:PT_FreeText
		$w->endTag(); #base2:individualName
		
		$w->startTag([$NS{base2}, 'organisationName']);
			$w->startTag([$NS{gmd}, 'PT_FreeText']);
				$w->startTag([$NS{gmd}, 'textGroup']);
					$w->dataElement([$NS{gmd}, 'LocalisedCharacterString'], 'Arpa Puglia');
				$w->endTag(); #gmd:textGroup
			$w->endTag(); #gmd:PT_FreeText
		$w->endTag(); #base2:individualName
		
		$w->startTag([$NS{base2}, 'contact']);
			$w->startTag([$NS{base2}, 'Contact']);
				$w->startTag([$NS{base2}, 'address']);
				
					$w->startTag([$NS{ad}, 'AddressRepresentation']);
						$w->startTag([$NS{ad}, 'adminUnit']);
							$w->startTag([$NS{gn}, 'GeographicalName']);
								$w->dataElement([$NS{gn}, 'language'], 'it');
								$w->dataElement([$NS{gn}, 'nativeness'], 'it');
								$w->emptyTag([$NS{gn}, 'nameStatus'], 'nilReason' => 'unknown', [$NS{'xsi'}, 'nil'] => 'true');
								$w->emptyTag([$NS{gn}, 'sourceOfName'], 'nilReason' => 'unknown', [$NS{'xsi'}, 'nil'] => 'true');
								$w->emptyTag([$NS{gn}, 'pronunciation'], 'nilReason' => 'unknown', [$NS{'xsi'}, 'nil'] => 'true');
								$w->startTag([$NS{gn}, 'spelling']);
									$w->startTag([$NS{gn}, 'SpellingOfName']);
										$w->dataElement([$NS{gn}, 'text'], 'Corso Trieste, 27 70126 - Bari (Italia)');
										$w->emptyTag([$NS{gn}, 'script'], 'nilReason' => 'unknown', [$NS{'xsi'}, 'nil'] => 'true');
									$w->endTag(); #gn:SpellingOfName
								$w->endTag(); #gn:spelling
							$w->endTag(); #gn:GeographicalName
						$w->endTag(); #ad:adminUnit
						$w->dataElement([$NS{ad}, 'locatorDesignator'], 'Bari');
						$w->dataElement([$NS{ad}, 'postCode'], '70126');
					$w->endTag(); #ad:AddressRepresentation
				$w->endTag(); #base2:address
				$w->dataElement([$NS{base2}, 'electronicMailAddress'], '<email> @ <domain>');
				$w->dataElement([$NS{base2}, 'telephoneVoice'], '+39 080/5460602');
				$w->dataElement([$NS{base2}, 'website'], 'www.arpa.puglia.it');
			$w->endTag(); #base2:Contact
		$w->endTag(); #base2:contact
	$w->endTag(); #base2:RelatedParty
}

# Casi possibili
#duration	duration_unit	cadence	cadence_unit	inq
#1			continuous		1	hour	Altri
#24			hour			1	day	    PM10/PM2.5
#2			hour			2	hour	PM10/PM2.5
#1			hour			1	hour	PM10/PM2.5
sub generaFrequenzeCampionamento {
	my $nome_inquinante = shift;
	
	my $frequenze_campionamento = [
		{duration_num_units => '1', duration_unit => 'continuous', cadence_num_units => '1', cadence_unit => 'hour'},
	];
	
	if ($nome_inquinante eq 'PM10' || $nome_inquinante eq 'PM2.5') {
		$frequenze_campionamento = [
			{duration_num_units => '24', duration_unit => 'hour', cadence_num_units => '1', cadence_unit =>  'day'},
			{duration_num_units =>  '2', duration_unit => 'hour', cadence_num_units => '2', cadence_unit => 'hour'},
			{duration_num_units =>  '1', duration_unit => 'hour', cadence_num_units => '1', cadence_unit => 'hour'},
		];
	}
	
	if ( grep { $_ eq $nome_inquinante} ('Pb', 'Cd', 'Ni', 'As', 'BaP') ) {
		$frequenze_campionamento = [
			{duration_num_units => '1', duration_unit => 'day', cadence_num_units => '1', cadence_unit =>  'day'},
		];
	}
	
	return $frequenze_campionamento;
}

sub calcolaFrequenzaCampionamento {
	my $inquinante = shift;
	
	my $frequenza_campionamento = {duration_num_units => '1', duration_unit => 'continuous', cadence_num_units => '1', cadence_unit => 'hour'};
	
	if ($inquinante->{nome} eq 'PM10' || $inquinante->{nome} eq 'PM2.5') {
		
		if ($inquinante->{is_biorario}) {
			$frequenza_campionamento = 	{duration_num_units =>  '2', duration_unit => 'hour', cadence_num_units => '2', cadence_unit => 'hour'};
		} elsif ($inquinante->{is_orario}) {
			$frequenza_campionamento = 	{duration_num_units =>  '1', duration_unit => 'hour', cadence_num_units => '1', cadence_unit => 'hour'};
		} else {
			$frequenza_campionamento = 	{duration_num_units => '24', duration_unit => 'hour', cadence_num_units => '1', cadence_unit =>  'day'};
		}	
	}
	
	if ( $inquinante->{tipo_misura} eq 'active' ) {
		$frequenza_campionamento = {duration_num_units => '1', duration_unit => 'day', cadence_num_units => '1', cadence_unit =>  'day'};
	}
	
	return $frequenza_campionamento;
}

1;
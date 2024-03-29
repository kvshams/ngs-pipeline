use strict;
use Vcf;
use Getopt::Long;
use Data::Dumper;
####### constants ############
my $excel_string_length_limit = 32759;

####### get arguments      ###
my ( $in, $out, $addings, $annotation_types_file, $log_file );
GetOptions(
	'in=s'  => \$in,
	'out=s' => \$out,
	'addings=s' => \$addings,
	'annotation_types_file=s' => \$annotation_types_file,
	'log_file=s' => \$log_file,
);

my @addings = split (",", $addings);

my $types = get_annotation_types($annotation_types_file);

my $vcf = Vcf->new( file => $in );
$vcf->parse_header( silent => 1 );
my $header     = $vcf->format_header();
my $vep_format = $1
  if $header =~
  m/Description=\"Consequence type as predicted by VEP. Format: (.+?)\"/;
my @vep_format = split( '\|', $vep_format );
my @blank_result = map { "" } @vep_format;
my @hgmd_format = qw/HGMD.HGMDID HGMD.confidence HGMD.disease/;
my @KG_format = qw/KG_FREQ.AF KG_FREQ.AFR_AF KG_FREQ.AMR_AF KG_FREQ.ASN_AF KG_FREQ.EUR_AF/;

# Do some simple parsing. Most thorough but slowest way how to get the data.
my @result_header = (
	'CHROM',    'POS',    'ID',    'REF',     'ALT',      'AF',
	'PROGRAM',  'SVTYPE', 'SVLEN', 'END',     
	@KG_format,
	'CGI_FREQ', 'FILTER', 'CASE',  'CONTROL', @addings, @hgmd_format, @vep_format, 
);

my $num_vep_format = scalar @vep_format;

open LOG, ">$log_file" or die "Can't open $log_file file for writing logs\n";
open OUT, ">$out" or die "Can't open $out file for writing results\n";

print OUT join( "\t", @result_header ), "\n";
my $exon_num   = get_feature_num_by_title( \@vep_format, 'EXON' );
my $intron_num = get_feature_num_by_title( \@vep_format, 'INTRON' );
my $consequence_num = get_feature_num_by_title( \@vep_format, 'Consequence' );

while ( my $x = $vcf->next_data_hash() ) {
	my $ref         = safe_excel_string( [ $x->{'REF'} ] );
	my $alt_alleles = safe_excel_string( $x->{'ALT'} );
	my $filter      = join( ',', @{ $x->{'FILTER'} } );
	my @csq         = split( ",", $x->{'INFO'}->{'CSQ'} );
###INFO=<ID=CSQ,Number=.,Type=String,Description="Consequence type as predicted by VEP. Format: Allele|Gene|Feature|Feature_type|Consequence|cDNA_position|CDS_position|Protein_position|Amino_acids|Codons|Existing_variation|PolyPhen|SIFT|CANONICAL|EXON|INTRON|CCDS">

	my @first_ann = (
		$x->{'CHROM'},
		$x->{'POS'},
		$x->{'ID'},
		$ref,
		$alt_alleles,
		$x->{'INFO'}->{'AF'},
		$x->{'INFO'}->{'set'},
		$x->{'INFO'}->{'SVTYPE'},
		$x->{'INFO'}->{'SVLEN'},
		$x->{'INFO'}->{'END'},
		(map {$x->{'INFO'}->{$_}} @KG_format),
		$x->{'INFO'}->{'CGI_FREQ.AF'},
		$filter,
		$x->{'INFO'}->{'CASE.set'},
		$x->{'INFO'}->{'CONTROL.set'},	
	);
	my @second_ann = (
		(map {$x->{'INFO'}->{$_}} @addings),
	);	
	my @third_ann = (
		(map {$x->{'INFO'}->{$_}} @hgmd_format),
	);
	my @first_to_print = (
		@first_ann,
		@second_ann,
		@third_ann
	);
	for my $csq (@csq) {
		$csq =~ s/\|$/\|./;
		my @vep_effect = split( '\|', $csq );
		my $consequence = $vep_effect[$consequence_num];
		if(exists $types->{$consequence}){
			next unless $types->{$consequence};
		}
		else{
			print LOG "$consequence\n";
		}
		$vep_effect[$exon_num]   =~ s/\//|/;
		$vep_effect[$intron_num] =~ s/\//|/;
		if ( scalar @vep_effect == $num_vep_format - 1 ) {
			push( @vep_effect, "" );
		}
		print OUT join( "\t", ( @first_to_print, @vep_effect ) ), "\n";
	}
	unless ( scalar @csq ) {
		print OUT join( "\t", ( @first_to_print, @blank_result ) ), "\n";
	}
}

close OUT;
close LOG;

sub get_feature_num_by_title {
	my ( $titles, $name ) = @_;
	my $i = 0;
	for my $t (@$titles) {
		last if $t eq $name;
		$i++;
	}
	return $i;
}
sub get_annotation_types{
	my ($file,) = @_;
	my $types = {};
	open FILE, "$file" or die "Can't open $file with annotation types for reading!\n";
	my $header = <FILE>;
	while(<FILE>){
		chomp;
		my @d = split "\t";
		$types->{$d[0]} = $d[1];
	}
	close FILE;
	return $types;
}

sub safe_excel_string {
	my ($array) = @_;
	my $result_string = join( ',', @{$array} );
	if ( length $result_string >= $excel_string_length_limit ) {
		my $i = 0;
		$result_string = join( ',', map { $i++; "LONG_ALLELE$i" } @{$array} );
	}
	return $result_string;
}


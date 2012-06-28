use strict;
use Vcf;
use Getopt::Long;
use Data::Dumper;
####### constants ############
my $excel_string_length_limit = 32759;

####### get arguments      ###
my ( $in, $out );
GetOptions(
	'in=s'  => \$in,
	'out=s' => \$out,
);

my $vcf = Vcf->new( file => $in );
$vcf->parse_header( silent => 1 );
my $header     = $vcf->format_header();
my $vep_format = $1
  if $header =~
  m/Description=\"Consequence type as predicted by VEP. Format: (.+?)\"/;
my @vep_format = split( '\|', $vep_format );
my @blank_result = map { "" } @vep_format;
my @hgmd_format = qw/HGMDID confidence disease/;

# Do some simple parsing. Most thorough but slowest way how to get the data.
my @result_header = (
	'CHROM',    'POS',    'ID',    'REF',     'ALT',      'AF',
	'PROGRAM',  'SVTYPE', 'SVLEN', 'END',     'CGI_FREQ', 'KG_FREQ',
	'EUR_FREQ', 'FILTER', 'CASE',  'CONTROL', @hgmd_format, @vep_format, 
);

my $num_vep_format = scalar @vep_format;

open OUT, ">$out" or die "Can't open $out file for writing results\n";

print OUT join( "\t", @result_header ), "\n";
my $exon_num   = get_feature_num_by_title( \@vep_format, 'EXON' );
my $intron_num = get_feature_num_by_title( \@vep_format, 'INTRON' );
while ( my $x = $vcf->next_data_hash() ) {
	my $ref         = safe_excel_string( [ $x->{'REF'} ] );
	my $alt_alleles = safe_excel_string( $x->{'ALT'} );
	my $filter      = join( ',', @{ $x->{'FILTER'} } );
	my @csq         = split( ",", $x->{'INFO'}->{'CSQ'} );
###INFO=<ID=CSQ,Number=.,Type=String,Description="Consequence type as predicted by VEP. Format: Allele|Gene|Feature|Feature_type|Consequence|cDNA_position|CDS_position|Protein_position|Amino_acids|Codons|Existing_variation|PolyPhen|SIFT|CANONICAL|EXON|INTRON|CCDS">
	my @first_to_print = (
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
		$x->{'INFO'}->{'CGI_FREQ.AF'},
		$x->{'INFO'}->{'KG_FREQ.AF'},
		$x->{'INFO'}->{'EUR_FREQ.AF'},
		$filter,
		$x->{'INFO'}->{'CASE.set'},
		$x->{'INFO'}->{'CONTROL.set'},
		$x->{'INFO'}->{'HGMDID'},
		$x->{'INFO'}->{'confidence'},
		$x->{'INFO'}->{'disease'},
	);
	for my $csq (@csq) {
		my @vep_effect = split( '\|', $csq );
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

sub get_feature_num_by_title {
	my ( $titles, $name ) = @_;
	my $i = 0;
	for my $t (@$titles) {
		last if $t eq $name;
		$i++;
	}
	return $i;
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


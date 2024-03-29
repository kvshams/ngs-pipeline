package Program;

sub new {
	my ( $class, %params ) = @_;
	my $self = {};
	my %all_params = ( %{ $params{params} }, %params );
	while ( my ( $key, $value ) = each %all_params ) {
		$self->{$key} = $value;
	}
	bless $self, $class;
	return $self;
}

sub additional_params {
	my ( $self, $additional_params ) = @_;
	my @params;
	@params = @{$self->{additional_params}}  if $self->{additional_params};
	@params = (@params,@$additional_params) if $additional_params;
	$self->{additional_params} = \@params if $additional_params;
	return $self->{additional_params};
}
sub clean_additional_params {
	my ( $self,  ) = @_;
	$self->{additional_params} = [];
}
sub basic_params {
	my ( $self, $basic_params ) = @_;
	if($basic_params){
		if($self->{basic_params}){
			my @p = (@{$self->{basic_params}}, @$basic_params);
			$self->{basic_params} = \@p;
		}
		else{
			$self->{basic_params} = $basic_params;
		}
	}
	
	return $self->{basic_params};
}

sub name {
	my ( $self, $name ) = @_;
	$self->{name} = $name if $name;
	return $self->{name};
}

sub path {
	my ( $self, $path ) = @_;
	$self->{path} = $path if $path;
	return $self->{path};
}

sub tmp_dir {
	my ( $self, $tmp_dir ) = @_;
	$self->{tmp_dir} = $tmp_dir if $tmp_dir;
	return $self->{tmp_dir};
}

sub prefix {
	my ( $self, $prefix ) = @_;
	$self->{prefix} = $prefix if $prefix;
	return $self->{prefix};
}

sub memory {
	my ( $self, $memory ) = @_;
	$self->{memory} = $memory if $memory;
	return $self->{memory};
}

sub to_string {
	my ( $self, ) = @_;
	my $path = $self->path;
	$path =~ s/\/$//;
	my $full_program = $path . '/' . $self->name;
	my @all          = (
		$self->prefix, $full_program,
		@{ $self->additional_params },
		@{ $self->basic_params }
	);
	my $string = join( " ", @all );
	$string =~ s/^\s+//;
	$string =~ s/\s{2,}/ /;
	return $string;
}
1;

package JavaProgram;
our @ISA = qw( Program );

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	bless $self, $class;
	return $self;
}

sub prefix {
	my ( $self, ) = @_;
	return "java -Xmx" . $self->memory . "g -jar";
}
1;

package PerlProgram;
our @ISA = qw( Program );

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	bless $self, $class;
	return $self;
}

sub prefix {
	my ( $self, $prefix ) = @_;
	$self->{prefix} = $prefix if $prefix;
	return $self->{prefix};
}
1;
package BedToolsProgram;
our @ISA = qw( Program );

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	bless $self, $class;
	return $self;
}

1;

package SamtoolsProgram;
our @ISA = qw( Program );

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	bless $self, $class;
	return $self;
}

1;



package PicardProgram;
our @ISA = qw( JavaProgram );

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	bless $self, $class;
	return $self;
}

sub basic_params {
	my ($self) = @_;
	return [
		"TMP_DIR=" . $self->{tmp_dir}, "VALIDATION_STRINGENCY=SILENT",
		"MAX_RECORDS_IN_RAM=2250000",
	];
}

1;

package GATKProgram;
our @ISA = qw( JavaProgram );

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);
	bless $self, $class;
	$self->name("GenomeAnalysisTK.jar");
	return $self;
}

1;

package JobManager;
use strict;
use Data::Dumper;

sub new {
	my ( $class, $debug) = @_;
	my $self = {
		string_ids => {},
		outputs => {},
		jobs => [],
		count      => 0,
		debug => $debug,
	};

	#Should include
	bless $self, $class;
	return $self;
}

sub debug{
	my ( $self, ) = @_;
	return $self->{debug};
}

sub register {
	my ( $self, $job ) = @_;
	push(@{$self->{jobs}}, $job);
	my $string_id = $job->string_id();
	$string_id .= "_" . $self->new_job_id();
	$self->{string_ids}->{$string_id} = $job;
	$self->initialize_dependencies($job);
}
sub initialize_dependencies {
	my ( $self, $job ) = @_;
	my $previous = $job->previous();
	for my $prev (@$previous){
		$prev->next($job);
	}
}
sub ensure_output_uniqueness {
	my ( $self, $job ) = @_;
	if(exists $self->{outputs}->{$job->out}){
		die "Duplicate outputs: " . $job->{out} . "\n";	
	}
	else{
		$self->{outputs}->{$job->out} = 1;
	}
	return $self->{jobs};
}
sub jobs {
	my ( $self, ) = @_;
	return $self->{jobs};
}
sub new_job_id {
	my ( $self, ) = @_;
	$self->{count} = 1 + $self->{count};
	return $self->{count};
}

sub list_jobs {
	my ( $self, $stream ) = @_;
	for my $job_string_id ( keys %{ $self->{string_ids} } ) {
		print $stream $job_string_id, "\n";
	}
}

sub start {
	my ( $self, $mode ) = @_;
	my $tasks = get_tasks($mode);
	my $jobs = $self->jobs();
	for my $job(@$jobs){
		$job->submit();
	}
}
sub clean{
	my ( $self,  ) = @_;
	my $jobs = $self->jobs();
	my $output = {};
	my @deletion;
	my @files;
	for my $job (@$jobs){
		for my $out ($job->do_not_delete){
			$output->{$out} = 1;
		}
		for my $file ($job->get_output_files){
			push (@files, $file);
		}
	}
	for my $file (@files){
		unless(exists $output->{$file}){
			my $command = "echo deleted > $file";
			system($command) unless $self->debug;
			print "$command\n";
		}
		
	}
}

sub get_tasks {
	my ($mode) = @_;
	my @task_types = qw/ALIGN DEDUP VARIATION SV EFFECT COVERAGE ALL/;
	my %tasks = map { $_ => 0 } @task_types;

	my @modes = split( /,/, $mode );
	if ( $mode =~ m/ALL/ ) {
		for my $t ( keys %tasks ) {
			$tasks{$t} = 1;
		}
	}
	for my $m (@modes) {
		if ( exists $tasks{$m} ) {
			$tasks{$m} = 1;
		}
		elsif ( $m =~ m/^NO_/ ) {
			$m =~ s/^NO_//;
			$tasks{$m} = 0;
		}
	}
	return \%tasks;
}
return 1;

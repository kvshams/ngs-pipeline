package TaskScheduler;
use strict;
use Data::Dumper;
my $global_qsub_params = '';

sub new {
	my ( $class, $project , $debug) = @_;

	my $self = {
		PROJECT => $project,
		DEBUG => $debug,
	};
	bless $self, $class;
	return $self;
}

sub submit_job {
	my ( $self, $job) = @_;
	my @ids = map {$_->job_id} @{$job->previous};
	my $qsub_params = $job->qsub_params;
	$qsub_params .= " -hold_jid " . join(",", @ids) unless $ids[0] eq undef;
	my $memory_qs  = 'mem_total=' . $job->memory() . 'G';
	my $memstr = " -l $memory_qs";
	$qsub_params .= $memstr;
	$self->make_script( $job);
	$self->run_script( $job, $qsub_params);
}

sub run_script {
	#my ( $self, $qsub_params, $job_id, $email, $dir) = @_;
	my ( $self, $job, $qsub_params) = @_;
	my $job_name = $job->job_name();
	my $project = $job->project;
	my $email = $project->{'CONFIG'}->{'EMAIL'};
	my $output_dir = $project->output_dir();
	my $error_dir = $project->error_dir();
	my $script_name = $self->_script_name($job_name);
	my $task_id_file = $job->task_id_file;
	my $task_line_end = "$script_name > $task_id_file";
	my $add_param = "$global_qsub_params -N $job_name -o $output_dir -e $error_dir";
	if ($qsub_params) {
		$qsub_params .= " $add_param";
	}
	else {
		$qsub_params = "$add_param";
	}
	my $task =
	  $qsub_params ? "qsub $qsub_params $task_line_end" : "qsub $task_line_end";
	print "$task\n";
	unless($self->{'DEBUG'}){
		system($task);
	}
}

sub make_script {
	#my ( $self, $user_id, $job_id, $program, $dir ) = @_;
	my ( $self, $job) = @_;
	my $job_name = $job->job_name();
	my $program = $job->program->to_string;
	my $project = $self->{'PROJECT'};
	my $user_id = $project->{'CONFIG'}->{'USER'};
	my $command = <<COMMAND;
#!/bin/sh
#
# Usage: sleeper.sh [time]]
#        default for time is 60 seconds

# -- $user_id ---
#\$ -N $job_name
#\$ -S /bin/sh
# Make sure that the .e and .o file arrive in the
# working directory
#\$ -cwd
#Merge the standard out and standard error to one file
#\$ -j y

export PATH=\$PATH:/data/software/bowtie-0.12.7
export PATH=\$PATH:/data/software/bwa-0.5.8c
export PATH=\$PATH:/data/software/samtools-0.1.12a
export PATH=\$PATH:/data/software/BEDTools-Version-2.10.1/bin
export PATH=\$PATH:/data/software/vcfCodingSnps.v1.5
export PATH=\$PATH:/data/software/tophat-1.2.0/bin
export PATH=\$PATH:/data/software/vcftools_0.1.4a/bin
export PATH=\$PATH:/data/software/tabix
export PERL5LIB=\$PERL5LIB:/data/software/breakdancer

$program
COMMAND
	my $script_name = $self->_script_name($job_name);	
	open( OUT, ">$script_name" )
	  or die "Can't open $script_name for writting\n";
	print OUT $command;
	print OUT "\n" . "echo 'done' > $script_name.done\n";
	close OUT;
}

sub _script_name {
	my ( $self, $job_name ) = @_;
	return $self->{'PROJECT'}->script_dir() . "/task.$job_name.script";
}

return 1;
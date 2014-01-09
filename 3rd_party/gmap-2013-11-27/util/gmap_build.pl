#! /usr/local/bin/perl
# $Id: gmap_build.pl.in 115881 2013-11-20 22:20:27Z twu $

use warnings;	

my $gmapdb = "/home/pap056/workspace/transcripts4community/jamg/3rd_party/gmap/../../databases/gmap/";
my $package_version = "2013-11-27";

use File::Copy;	
use Getopt::Long;

Getopt::Long::Configure(qw(no_auto_abbrev no_ignore_case_always));


# Default values
my $bindir = "/home/pap056/workspace/transcripts4community/jamg/3rd_party/gmap/../bin";
my $builddir = ".";
my $sampling = 3;
my $sleeptime = 2;

GetOptions(
    'no-sarray' => \$skip_sarray_p, # skip suffix array

    'B=s' => \$bindir,		# binary directory
    'T=s' => \$builddir,	# temporary build directory

    'D|dir=s' => \$destdir,	# destination directory
    'd|db=s' => \$dbname,	# genome name
    'n|names=s' => \$chrnamefile,   # substitute chromosomal names

    'M|mdfile=s' => \$mdfile,	# NCBI MD file
    'C|contigs-are-mapped' => \$contigs_mapped_p, # Each contig contains a chromosome tag in the FASTA header

    'z|compression=s' => \$compression_types, # compression types
    'k|kmer=s' => \$kmersize, # k-mer size for genomic index (allowed: 16 or less)
    'b|basesize=s' => \$basesize, # offsetscomp basesize
    'q=s' => \$sampling,	   # sampling interval for genome (default: 3)

    's|sort=s' => \$sorting,	# Sorting
    'g|gunzip' => \$gunzipp,	# gunzip files
    'E|fasta-pipe=s' => \$fasta_pipe,		  # Pipe for providing FASTA files

    'w=s' => \$sleeptime, # waits (sleeps) this many seconds between steps.  Useful if there is a delay in the filesystem.

    'c|circular=s' => \$circular,  # Circular chromosomes

    'e|nmessages=s' => \$nmessages  # Max number of warnings or messages to print
    );


if (defined($compression_types)) {
    $compression_flag = "-z $compression_types";
} else {
    $compression_flag = "";
}

if (!defined($kmersize)) {
    print STDERR "-k flag not specified, so building with default 15-mers\n";
    $kmersize = 15;
}

if (defined($compression_types)) {
    foreach $type (split ",",$compression_types) {
	if ($type eq "none") {
	    if (!defined($basesize)) {
		print STDERR "-b flag not specified, but since compression type is none, setting base size to be the k-mer size\n";
		$basesize = $kmersize;
	    } elsif ($basesize != $kmersize) {
		print STDERR "Since compression type is none, setting base size to be the k-mer size\n";
		$basesize = $kmersize;
	    }
	}
    }
}

if (!defined($basesize)) {
    if ($kmersize == 15) {
	print STDERR "-b flag not specified, so building with default base size of 12\n";
	$basesize = 12;
    } else {
	print STDERR "-k flag specified (not as 15), but not -b, so building with base size == kmer size\n";
	$basesize = $kmersize;
    }
}


if (!defined($dbname)) {
    print_usage();
    die "Must specify genome database name with -d flag.";
} elsif ($dbname =~ /(\S+)\/(\S+)/) {
    $dbdir = $1;
    $dbname = $2;
    if (defined($destdir) && $destdir =~ /\S/) {
	$destdir = $destdir . "/" . $dbname;
    } else {
	$destdir = $dbdir;
    }
}

$dbname =~ s/\/$//;	# In case user gives -d argument with trailing slash

if (!defined($destdir) || $destdir !~ /\S/) {
    print STDERR "Destination directory not defined with -D flag, so writing to $gmapdb\n";
    $destdir = $gmapdb;
}

if (defined($sorting)) {
    $chr_order_flag = "-s $sorting";
} else {
    # Default is to order genomes
    print STDERR "Sorting chromosomes in chrom order.  To turn off or sort other ways, use the -s flag.\n";
    $chr_order_flag = "";
}

if (!defined($gunzipp)) {
    $gunzip_flag = "";
} elsif (defined($fasta_pipe)) {
    die "Cannot use the -E (--fasta-pipe) flag with the -g (--gunzip) flag";
} else {
    $gunzip_flag = "-g";
}

if (defined($circular)) {
    $circular_flag = "-c $circular";
} else {
    $circular_flag = "";
}

if (defined($nmessages)) {
    $nmessages_flag = "-e $nmessages";
} else {
    $nmessages_flag = "";
}

if (defined($skip_sarray_p)) {
    $sarrayp = 0;
} else {
    $sarrayp = 1;
}

if (defined($contigs_mapped_p)) {
    $contigs_mapped_flag = "-C";
} else {
    $contigs_mapped_flag = "";
}



my @quoted = ();
foreach $fasta (@ARGV) {
    push @quoted,"\"$fasta\"";
}
my $genome_fasta = join(" ",@quoted);



#####################################################################################


create_genome_version($builddir,$dbname);

$coordsfile = create_coords($mdfile,$fasta_pipe,$gunzip_flag,$circular_flag,$contigs_mapped_flag,$chrnamefile,
			    $bindir,$builddir,$dbname,$genome_fasta);
if (!(-s "$coordsfile")) {
    die "ERROR: $coordsfile not found";
} else {
    $gmap_process_pipe = make_gmap_process_pipe($fasta_pipe,$gunzip_flag,$bindir,$coordsfile,$genome_fasta);
}

make_contig($nmessages_flag,$chr_order_flag,
	    $bindir,$builddir,$dbname,$gmap_process_pipe);

$genomecompfile = compress_genome($nmessages_flag,$bindir,$builddir,$dbname,$gmap_process_pipe);

unshuffle_genome($bindir,$builddir,$dbname,$genomecompfile);

$index_cmd = "$bindir/gmapindex -b $basesize -k $kmersize -q $sampling $nmessages_flag -d $dbname -F $builddir -D $builddir";

if (count_index_offsets($index_cmd,$genomecompfile) == 1) {
    $index_cmd .= " -H";
}

create_index_offsets($index_cmd,$compression_flag,$genomecompfile);

create_index_positions($index_cmd,$genomecompfile);

if ($sarrayp == 1) {
    make_suffix_array($bindir,$builddir,$dbname);
}
install_db($sarrayp);

exit;


#####################################################################################

sub create_genome_version {
    my ($builddir, $dbname) = @_;

    open GENOMEVERSIONFILE, ">$builddir/$dbname.version" or die $!;
    print GENOMEVERSIONFILE "$dbname\n";
    close GENOMEVERSIONFILE or die $!;
    sleep($sleeptime);
    return;
}

sub create_coords {
    my ($mdfile, $fasta_pipe, $gunzip_flag, $circular_flag, $contigs_mapped_flag, $chrnamefile,
	$bindir, $builddir, $dbname, $genome_fasta) = @_;
    my $coordsfile = "$builddir/$dbname.coords";
    my ($cmd, $rc);

    if (defined($mdfile)) {
	# MD file cannot specify that a chromosome is circular
	$cmd = "$bindir/md_coords -o $coordsfile $mdfile";
    } else {
	if (defined($fasta_pipe)) {
	    $cmd = "$fasta_pipe | $bindir/fa_coords $circular_flag $contigs_mapped_flag -o $coordsfile";
	} else {
	    $cmd = "$bindir/fa_coords $gunzip_flag $circular_flag $contigs_mapped_flag -o $coordsfile";
	}
	if (defined($chrnamefile)) {
	    $cmd .= " -n $chrnamefile";
	}
	if (!defined($fasta_pipe)) {
	    $cmd .= " $genome_fasta";
	}
    }
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return $coordsfile;
}

sub make_gmap_process_pipe {
    my ($fasta_pipe, $gunzip_flag, $bindir, $coordsfile, $genome_fasta) = @_;

    if (defined($fasta_pipe)) {
	return "$fasta_pipe | $bindir/gmap_process -c $coordsfile";
    } else {
	return "$bindir/gmap_process $gunzip_flag -c $coordsfile $genome_fasta";
    }
}

sub make_contig {
    my ($nmessages_flag, $chr_order_flag,
	$bindir, $builddir, $dbname, $gmap_process_pipe) = @_;
    my ($cmd, $rc);

    $cmd = "$gmap_process_pipe | $bindir/gmapindex $nmessages_flag -d $dbname -D $builddir -A $chr_order_flag";
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return;
}

sub compress_genome {
    my ($nmessages_flag, $bindir, $builddir, $dbname, $gmap_process_pipe) = @_;
    my $genomecompfile = "$builddir/$dbname.genomecomp";
    my ($cmd, $rc);

    $cmd = "$gmap_process_pipe | $bindir/gmapindex $nmessages_flag -d $dbname -F $builddir -D $builddir -G";
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return $genomecompfile;
}

sub unshuffle_genome {
    my ($bindir, $builddir, $dbname, $genomecompfile) = @_;
    my ($cmd, $rc);

    $cmd = "cat $genomecompfile | $bindir/gmapindex -d $dbname -U > $builddir/$dbname.genomebits";
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return;
}

# No longer supported
#sub full_ASCII_genome {
#    make_contig();
#	
#    $cmd = "$bindir/gmap_process $gunzip_flag -c $builddir/$dbname.coords $genome_fasta | $bindir/gmapindex $nmessages_flag -d $dbname -F $builddir -D $builddir -l -G";
#    print STDERR "Running $cmd\n";
#    if (($rc = system($cmd)) != 0) {
#	die "$cmd failed with return code $rc";
#    }
#    sleep($sleeptime);
#    return;
#}

sub count_index_offsets {
    my ($index_cmd, $genomecompfile) = @_;
    my $huge_genome_p;
    my ($cmd, $noffsets);
    
    $cmd = "cat $genomecompfile | $index_cmd -C";
    print STDERR "Running $cmd\n";
    $noffsets = `$cmd`;
    chop $noffsets;
    if ($noffsets <= 4294967295) {
	print STDERR "Number of offsets: $noffsets => pages file not required\n";
	$huge_genome_p = 0;
    } else {
	print STDERR "Number of offsets: $noffsets => pages file required\n";
	$huge_genome_p = 1;
    }
    sleep($sleeptime);
    return $huge_genome_p;
}

sub create_index_offsets {
    my ($index_cmd, $compression_flag, $genomecompfile) = @_;
    my ($cmd, $rc);

    $cmd = "cat $genomecompfile | $index_cmd -O $compression_flag";
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return;
}

sub create_index_positions {
    my ($index_cmd, $genomecompfile) = @_;
    my ($cmd, $rc);

    $cmd = "cat $genomecompfile | $index_cmd -P";
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return;
}

sub make_suffix_array {
    my ($bindir, $builddir, $dbname) = @_;
    my ($cmd, $rc);

    $cmd = "$bindir/gmapindex -d $dbname -F $builddir -D $builddir -S";
    print STDERR "Running $cmd\n";
    if (($rc = system($cmd)) != 0) {
	die "$cmd failed with return code $rc";
    }
    sleep($sleeptime);
    return;
}

sub install_db {
    my ($sarrayp) = @_;
    my @suffixes = (
	"chromosome", 
	"chromosome.iit", 
	"chrsubset", 
	"contig", 
	"contig.iit", 
	"genomecomp", 
	"genomebits", 
	"version");
    my $suffix;
    my %symlink;

    if ($sarrayp == 1) {
	push @suffixes,"sarray";
	push @suffixes,"saindex";
	push @suffixes,"salcp";	# No longer generated
	push @suffixes,"salcpptrs";
	push @suffixes,"salcpcomp";
    }
	
    if ($kmersize > $basesize) {
	push @suffixes,sprintf "ref%02d%02d%dbitpackpages",$kmersize-3,$kmersize,$sampling;
	push @suffixes,sprintf "ref%02d%02d%dbitpackptrs",$kmersize-3,$kmersize,$sampling;
	push @suffixes,sprintf "ref%02d%02d%dbitpackcomp",$kmersize-3,$kmersize,$sampling;
	push @suffixes,sprintf "ref%02d%02d%dgammaptrs",$basesize,$kmersize,$sampling;
	push @suffixes,sprintf "ref%02d%02d%doffsetscomp",$basesize,$kmersize,$sampling;
    } else {
	$suffix = sprintf "ref%02d%doffsets",$kmersize,$sampling;
	push @suffixes,$suffix;
	
	# For backward compatibility with versions before 2013-07, which expect to see offsetscomp
	$symlink{$suffix} = sprintf "ref%02d%02d%doffsetscomp",$kmersize,$kmersize,$sampling;
    }
    push @suffixes,sprintf "ref%02d%dpositionsh",$kmersize,$sampling;
    push @suffixes,sprintf "ref%02d%dpositions",$kmersize,$sampling;

    print STDERR "Copying files to directory $destdir/$dbname\n";
    system("mkdir -p \"$destdir/$dbname\"");
    system("mkdir -p \"$destdir/$dbname/$dbname.maps\"");
    system("chmod 755 \"$destdir/$dbname/$dbname.maps\"");
    foreach $suffix (@suffixes) {
	if (-e "$builddir/$dbname.$suffix") {
	    system("mv \"$builddir/$dbname.$suffix\" \"$destdir/$dbname/$dbname.$suffix\"");
	    system("chmod 644 \"$destdir/$dbname/$dbname.$suffix\"");
	    if (defined($symlink{$suffix})) {
		system("ln -s \"$dbname.$suffix\" \"$destdir/$dbname/$dbname.$symlink{$suffix}\"");
	    }
	}
    }

    system("rm -f \"$builddir/$dbname.coords\"");

    return;
}



sub print_usage {
  print <<TEXT1;

gmap_build: Builds a gmap database for a genome to be used by GMAP or GSNAP.
Part of GMAP package, version $package_version.

A simplified alternative to using the program gmap_setup, which creates a Makefile.

Usage: gmap_build [options...] -d <genomename> <fasta_files>

Options:
    -D, --dir=STRING          Destination directory for installation (defaults to gmapdb directory specified at configure time)
    -d, --db=STRING           Genome name

    -n, --names=STRING        Substitute names for chromosomes, provided in a file.  The file should have one line
                                for each chromosome name to be changed, with the original FASTA name in column 1 and
                                the desired chromosome name in column 2.  This provides an easy way to change the
                                names of chromosomes, for example, to add or remove the "chr" prefix.

    -T STRING                 Temporary build directory (may need to specify if you run out of space in your current directory)

    -M, --mdflag=STRING       Use MD file from NCBI for mapping contigs to chromosomal coordinates
    -C, --contigs-are-mapped  Find a chromosomal region in each FASTA header line.  Useful for contigs that have been mapped
                                to chromosomal coordinates.  Ignored if the --mdflag is provided.

    -z, --compression=STRING  Use given compression types (separated by commas; default is bitpack,gamma)
                                bitpack - optimized for modern computers with SIMD instructions (recommended)
                                gamma - old implementation.  Needed only for backward compatibility with old versions
                                all - create all available compression types, currently bitpack and gamma
                                none - do not compress offset files

    -k, --kmer=INT            k-mer value for genomic index (allowed: 16 or less, default is 15)
    -b, --basesize=INT        Basesize for offsetscomp (if kmer chosen and not 15, default is kmer; else default is 12)
    -q INT                    sampling interval for genomoe (allowed: 1-3, default 3)

    -s, --sort=STRING         Sort chromosomes using given method:
			        none - use chromosomes as found in FASTA file(s)
			        alpha - sort chromosomes alphabetically (chr10 before chr 1)
			        numeric-alpha - chr1, chr1U, chr2, chrM, chrU, chrX, chrY
			        chrom - chr1, chr2, chrM, chrX, chrY, chr1U, chrU

    -g, --gunzip              Files are gzipped, so need to gunzip each file first
    -E, --fasta-pipe=STRING   Interpret argument as a command, instead of a list of FASTA files
    -w INT                    Wait (sleep) this many seconds after each step (default 2)

    -c, --circular=STRING     Circular chromosomes (either a list of chromosomes separated by a comma, or
                                a filename containing circular chromosomes, one per line).  If you use the
                                --names feature, then you should use the original name of the chromosome,
                                not the substitute name, for this option.                                                                

    -e, --nmessages=INT       Maximum number of messages (warnings, contig reports) to report (default 50)

    --no-sarray               Skip build of suffix array
TEXT1
  return;
}

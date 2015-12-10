package Devel::PatchPerl::Plugin::BenchmarkVirtualError;

# ABSTRACT: Avoid failures on Benchmark.t when building under certain virtual machines

use base 'Devel::PatchPerl';

sub patchperl {
  my $class = shift;
  my %args = @_;
  my ($vers, $source, $patch_exe) = @args{qw(version source patchexe)};
  for my $p ( grep { Devel::PatchPerl::_is( $_->{perl}, $vers ) } @Devel::PatchPerl::patch ) {
    for my $s (@{$p->{subs}}) {
      my ($sub, @args) = @$s;
      push @args, $vers unless scalar @args;
      $sub->(@args);
    }
  }
}


package
    Devel::PatchPerl;

use vars '@patch';

@patch = (
    {
        perl => [ qr/^5\.(1|20)/ ],
        subs => [ [\&_patch_benchmarkvirtualerror] ],
    },
);

sub _patch_benchmarkvirtualerror {

    _patch(<<'EOP');
diff --git lib/Benchmark.pm lib/Benchmark.pm
index 9a43a2b..73b3211 100644
--- lib/Benchmark.pm
+++ lib/Benchmark.pm
@@ -700,8 +700,18 @@ sub runloop {
     # getting a too low initial $n in the initial, 'find the minimum' loop
     # in &countit.  This, in turn, can reduce the number of calls to
     # &runloop a lot, and thus reduce additive errors.
+    #
+    # Note that its possible for the act of reading the system clock to
+    # burn lots of system CPU while we burn very little user clock in the
+    # busy loop, which can cause the loop to run for a very long wall time.
+    # So gradually ramp up the duration of the loop. See RT #122003
+    #
     my $tbase = Benchmark->new(0)->[1];
-    while ( ( $t0 = Benchmark->new(0) )->[1] == $tbase ) {} ;
+    my $limit = 1;
+    while ( ( $t0 = Benchmark->new(0) )->[1] == $tbase ) {
+        for (my $i=0; $i < $limit; $i++) { my $x = $i / 1.5 } # burn user CPU
+        $limit *= 1.1;
+    }
     $subref->();
     $t1 = Benchmark->new($n);
     $td = &timediff($t1, $t0);
EOP
}

!!42;
__END__

=head1 SYNOPSIS

    $ export PERL5_PATCHPERL_PLUGIN=BenchmarkVirtualError
    $ perl-build ...

=head1 DESCRIPTION

See L<RT #122003|https://rt.perl.org/Public/Bug/Display.html?id=122003>

=head1 SEE ALSO

https://rt.perl.org/Public/Bug/Display.html?id=122003

=cut

package Module::Loader;

=head1 NAME

Module::Loader - Load modules dynamically and installs missing ones

=head1 DESCRIPTION

This module does exactly what it says on the tin. It's a module loader. You can load multiple modules in one go by importing them with Module::Loader, or load a single one with C<load_module>, which also accepts an array to pass to the module.
Module::Loader comes with some import options to switch on/off verbose information and the optional ability to automatically download any missing modules once the script exists. Please be aware this feature is still under heavy development and needs some tweaking. For it to work properly you'll want to make sure you don't need sudo to install modules (ie: App::perlbrew).

=head1 SYNOPSIS


    use Module::Loader qw/
        Goose
        Try::Tiny
    /;

Or to load a single module
    
    BEGIN {
        load_module 'Moose';
        load_module 'Try::Tiny';
        load_module 'Goose' => qw/:Debug :UseMoose/;
    }   

=head1 TRIGGERS

Module::Loader has 3 tiggers, which are all OFF by default. Triggers can be turned on 
by passing it as an import option when you C<use Module::Loader>. All options MUST have a ':' in 
front of them or it will try to load it as a module.

    use Module::Loader qw/
        :InstallMissing
        :Complain
        
        Goose
    /;

C<:InstallMissing> - Once the script exists, :InstallMissing will attempt to fetch any missing modules via cpanm (App::cpanminus).

C<:Complain> - This will turn on some minor verbose information, pretty much just saying it couldn't find a module without printing out the entire contents of @INC to your screen.

C<:Moan> - This trigger switches on :Complain, but will also display the normal ugly Perl errors for a bit more information in case you need it.

=cut

use 5.010;

our $VERSION = '0.003';
$Module::Loader::InstallMissing = 0;
$Module::Loader::Complain       = 0;
$Module::Loader::Moan           = 0;

sub import {
    my ($class, @modules) = @_;
    my $scope = _getscope();
    *{$scope . "::load_module"} = \&load_module;
    *{$scope . "::is_module_loaded"} = \&is_module_loaded;
    if (@modules == 1 && ref($modules[0])) {
        print STDERR __PACKAGE__ . ": Not expecting a reference\n";
        exit;
    }
    my $not_found = [];
    for my $mod (@modules) {
        if (substr($mod, 0, 1) eq ':') {
            # found a Module::Loader option
            _option($mod);
            next;
        }
        unless (scalar(@modules) == 0) {
            eval qq{
                package $scope;
                use $mod;
                1;
            };

            if ($@) {
                my $err = $@;
                if ($err =~ /Can't locate/) {
                    warn "Module::Loader - Couldn't load $mod. Not found.\n"
                        if $Module::Loader::Complain;
                    warn $@
                        if $Module::Loader::Moan;
                    push @$not_found, $mod;
                }
                else {
                    warn "Module::Loader - Couldn't load $mod because of an unknown error\n"
                        if $Module::Loader::Complain;
                    warn $@
                        if $Module::Loader::Moan;
                }
            }
        }
    }

    if (scalar @$not_found > 0) {
        if ($Module::Loader::InstallMissing) {
            my $pid;
            my $bin = _getbinpath();
            print "Installing missing modules using cpanm...\n";
            my $cpanm = "$bin/cpanm";
            unless ( -f $cpanm ) {
                die "Cannot fetch modules if cpanm is not installed. Please install App::cpanminus then re-run\n";
            }

            $SIG{CHLD} = sub { wait };
            
            unless ($pid = fork) {
                unless (fork) {
                    exec "$bin/cpanm  " . join(' ', @$not_found);
                }
                exit 0;
            }
            waitpid($pid, 0);
            print "Finished\n";
        }
        else {
            print STDERR "The following modules were missing, but will not be installed\n";
            for (@$not_found) {
                print STDERR "    $_\n";
            }
            print STDERR "\n";
        }
    }
}

sub _getscope {
    return (caller(1))[0];
}

sub _option {
    my $opt = shift;
    given($opt) {
        when (':InstallMissing') {
            $Module::Loader::InstallMissing = 1;
        }
        when (':Complain') {
            $Module::Loader::Complain = 1;
        }
        when (':Moan') {
            $Module::Loader::Complain = 1;
            $Module::Loader::Moan = 1;
        }
    }
}

sub _getbinpath {
    my $path;
    if ($ENV{_}) { $path = $ENV{_}; }
    else { $path = $^X; }
   
    if ($path) {
        $path = substr($path, 0, -4);
    }
    return $path||die "Could not get Perl binary path\n";
}

=head1 EXPORTED METHODS

=head2 load_module

This method, well, it loads a module. The difference between this and the other one is this can 
take an optional array to pass to the module on load, and you can use it to dynamically load other modules in your code.

    load_module 'ThisModule';
    load_module 'ThatModule => qw/exported_method something_else/;

=cut

sub load_module {
    my (@mod) = @_;
    my $scope = caller;
    my $has_attr = 0;
    my $name = shift @mod;
    $has_attr = 1
        if scalar(@mod) > 0;
    if ($has_attr) {
        my $attr = join ' ', @mod;
        eval qq{
            package $scope;
            use $name qw/$attr/;
            1;
        };
    }
    else {
        eval qq{
            package $scope;
            use $name;
            1;
        };
    }
}

=head2 is_module_loaded

Simply performs a little test to see if the specified module is loaded. Returns 1 on success, or 0 on failure

    if (is_module_loaded 'Goose') {
        print "It's loaded!\n";
    }
    else {
        print "Module not loaded :-(\n";
        load_module 'Goose';
    }

=cut

sub is_module_loaded {
    my $mod = shift;
    my $scope = _getscope();
    my $pkg = "$scope\::";
    my $match = 0;
    for (keys %$pkg) {
        $match++
            if $_ eq "$mod\::";
    }

    return 1 if $match > 0;
    return 0 if $match == 0;
}

=head1 BUGS

Please e-mail brad@geeksware.net

=head1 AUTHOR

Brad Haywood <brad@geeksware.net>

=head1 COPYRIGHT & LICENSE

Copyright 2011 the above author(s).

This sofware is free software, and is licensed under the same terms as perl itself.

=cut

1;

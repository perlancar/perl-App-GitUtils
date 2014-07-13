package App::GitUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Cwd;
use File::chdir;

our %SPEC;

our $_complete_program = sub {
    require Complete::Util;
    require List::MoreUtils;

    my %args = @_;

    my $word = $args{word} // '';
    my $completion;
    my $is_path;

    # combine all executables (including dirs) and programs in PATH
    my $c1 = Complete::Util::complete_file(
        word   => $word,
        filter => sub { -x $_[0] },
        #ci    => 1, # convenience, not yet supported by C::U
    );
    my $c2 = Complete::Util::complete_program(
        word => $word,
        ci   => 1, # convenience
    );

    {
        completion => [ List::MoreUtils::uniq(sort(@$c1, @$c2)) ],
        is_path    => 1,
    };
};

sub _search_program {
    require File::Which;

    my $prog = shift;
    if ($prog =~ m!/!) {
        return $prog;
    } else {
        return File::Which::which($prog) // $prog;
    }
}

sub _search_git_dir {
    my $orig_wd = getcwd;
    my $cwd = $orig_wd;

    my $res;
    while (1) {
        do { $res = "$cwd/.git"; last } if -d ".git";
        chdir ".." or return undef;
        $cwd =~ s!(.+)/.+!$1! or last;
    }

    chdir $orig_wd;
    return $res;
}

$SPEC{info} = {
    v => 1.1,
    summary => 'Return information about git repository',
};
sub info {
    my %args = @_;

    my $git_dir = _search_git_dir();
    return [412, "Can't find .git dir, make sure you're inside a git repo"]
        unless defined $git_dir;

    [200, "OK", {
        git_dir => $git_dir,
        # more information in the future
    }];
}

$SPEC{list_hooks} = {
    v => 1.1,
    summary => 'List available hooks for the repository',
};
sub list_hooks {
    my %args = @_;

    my $git_dir = _search_git_dir();
    return [412, "Can't find .git dir, make sure you're inside a git repo"]
        unless defined $git_dir;

    my $hooks_dir = "$git_dir/hooks";
    opendir my($dh), $hooks_dir;
    my @res;
    for (sort readdir $dh) {
        next if /\.sample\z/; # skip sample names
        next unless -f "$hooks_dir/$_" && -x _;
        push @res, $_;
    }
    [200, "OK", \@res];
}

$SPEC{run_hook} = {
    v => 1.1,
    summary => 'Run a hook',
    args => {
        name => {
            summary => 'Hook name, e.g. post-commit',
            schema => ['str*', match => '\A[A-Za-z0-9-]+\z'],
            req => 1,
            pos => 0,
        },
    },
};
sub run_hook {
    my %args = @_;

    my $git_dir = _search_git_dir();
    return [412, "Can't find .git dir, make sure you're inside a git repo"]
        unless defined $git_dir;

    my $name = $args{name};

    (-x "$git_dir/hooks/$name") or
        return [400, "Unknown or non-executable git hook: $name"];

    local $CWD = "$git_dir/..";
    exec ".git/hooks/$name";
    [200]; # unreached
}

$SPEC{post_commit} = {
    v => 1.1,
    summary => 'Run a hook',
    description => <<'_',

Basically the same as:

    % .git/hooks/post-commit

except can be done anywhere inside git repo.

_
    args => {
        name => {
            summary => 'Hook name, e.g. post-commit',
            schema => ['str*', match => '\A[A-Za-z0-9-]+\z'],
            req => 1,
            pos => 0,
        },
    },
};

1;
# ABSTRACT: Day-to-day command-line utilities for git

=head1 SYNOPSIS

This distribution provides the following command-line utilities:

 gu

These utilities provide some shortcuts and tab completion to make it more
convenient when working with git con the command-line.

More utilities will be added in the future.


=head1 SEE ALSO

=cut

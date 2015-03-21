package App::GitUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Cwd;
use File::chdir;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Day-to-day command-line utilities for git',
};

our $_complete_hook = sub {
    my %args = @_;

    my $word = $args{word} // '';
    my $res = list_hooks();
    return [] unless $res->[0] == 200;
    return $res->[2];
};

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
    description => <<'_',

Basically the same as:

    % .git/hooks/<hook-name>

except can be done anywhere inside git repo and provides tab completion.

_
    args => {
        name => {
            summary => 'Hook name, e.g. post-commit',
            schema => ['str*', match => '\A[A-Za-z0-9-]+\z'],
            req => 1,
            pos => 0,
            completion => $_complete_hook,
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
    #[200]; # unreached
}

$SPEC{post_commit} = {
    v => 1.1,
    summary => 'Run post-commit hook',
    description => <<'_',

Basically the same as:

    % .git/hooks/post-commit

except can be done anywhere inside git repo.

_
};
sub post_commit {
    run_hook(name => 'post-commit');
}

$SPEC{pre_commit} = {
    v => 1.1,
    summary => 'Run pre-commit hook',
    description => <<'_',

Basically the same as:

    % .git/hooks/pre-commit

except can be done anywhere inside git repo.

_
};
sub pre_commit {
    run_hook(name => 'pre-commit');
}

1;
# ABSTRACT:

=head1 SYNOPSIS

This distribution provides the following command-line utilities:

#INSERT_EXECS_LIST

These utilities provide some shortcuts and tab completion to make it more
convenient when working with git con the command-line.


=head1 FAQ

#INSERT_BLOCK: App::PMUtils faq


=head1 SEE ALSO

#INSERT_BLOCK: App::PMUtils see_also

=cut

package App::GitUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Cwd qw(getcwd abs_path);
use File::chdir;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Day-to-day command-line utilities for git',
};

our %argopt_dir = (
    dir => {
        summary => 'A directory inside git repo',
        schema => 'dirname*',
        description => <<'_',

If not specified, will assume current directory is inside git repository and
will search `.git` upwards.

_
    },
);

our %args_common = (
    %argopt_dir,
);

our %arg_target_dir = (
    target_dir => {
        summary => 'Target repo directory',
        schema => 'dirname*',
        description => <<'_',

If not specified, defaults to `$repodir.bare/`.

_
    },
);

our $_complete_hook = sub {
    my %args = @_;

    my $word = $args{word} // '';
    my $res = list_hooks();
    return [] unless $res->[0] == 200;
    return $res->[2];
};

sub _search_git_dir {
    my $args = shift;

    my $orig_wd = getcwd;

    my $cwd;
    if (defined $args->{dir}) {
        $cwd = $args->{dir};
    } else {
        $cwd = $orig_wd;
    }

    my $res;
    while (1) {
        do { $res = "$cwd/.git"; last } if -d ".git";
        chdir ".." or goto EXIT;
        $cwd =~ s!(.+)/.+!$1! or last;
    }

  EXIT:
    chdir $orig_wd;
    return $res;
}

$SPEC{info} = {
    v => 1.1,
    summary => 'Return information about git repository',
    args => {
        %args_common,
    },
};
sub info {
    my %args = @_;

    my $git_dir = _search_git_dir(\%args);
    return [412, "Can't find .git dir, make sure you're inside a git repo"]
        unless defined $git_dir;

    my ($repo_name) = $git_dir =~ m!.+/(.+)/\.git\z!
        or return [500, "Can't extract repo name from git dir '$git_dir'"];

    [200, "OK", {
        git_dir => $git_dir,
        repo_name => $repo_name,
        # more information in the future
    }];
}

$SPEC{list_hooks} = {
    v => 1.1,
    summary => 'List available hooks for the repository',
    args => {
        %args_common,
    },
};
sub list_hooks {
    my %args = @_;

    my $git_dir = _search_git_dir(\%args);
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
        %args_common,
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

    my $git_dir = _search_git_dir(\%args);
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
    args => {
        %args_common,
    },
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
    args => {
        %args_common,
    },
};
sub pre_commit {
    run_hook(name => 'pre-commit');
}

$SPEC{clone_to_bare} = {
    v => 1.1,
    summary => 'Clone repository to a bare repository',
    args => {
        %args_common,
        %arg_target_dir,
    },
};
sub clone_to_bare {
    require IPC::System::Options;

    my %args = @_;

    my $res = info(%args);
    return $res unless $res->[0] == 200;

    my $src_dir = "$res->[2]{git_dir}/..";
    my $target_dir = abs_path($args{target_dir} // "$src_dir/../$res->[2]{repo_name}.bare");
    (-d $target_dir) and return [412, "Target dir '$target_dir' already exists"];
    (-e $target_dir) and return [412, "Target '$target_dir' already exists but not a dir"];

    mkdir $target_dir, 0755 or return [500, "Can't mkdir target dir '$target_dir': $!"];
    IPC::System::Options::system(
        {log=>1, die=>1},
        "git", "init", "--bare", $target_dir,
    );

    local $CWD = $src_dir;
    IPC::System::Options::system(
        {log=>1, die=>1},
        "git", "push", $target_dir,
    );
    [200];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

This distribution provides the following command-line utilities:

#INSERT_EXECS_LIST

These utilities provide some shortcuts and tab completion to make it more
convenient when working with git con the command-line.


=cut

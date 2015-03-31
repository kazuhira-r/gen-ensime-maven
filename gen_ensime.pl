#!/usr/bin/perl

use strict;
use warnings;

my $sbt_build_file = '___gen_ensime.sbt';

my $scala_version = '2.11.6';

if (@ARGV ge 1) {
    $scala_version = $ARGV[0];
}

my @maven_dependency_tree = split /\r?\n/, `mvn dependency:tree`;

my $line_index = 0;

for (my $i  = 0; $i < @maven_dependency_tree; $i++) {
    if ($maven_dependency_tree[$i] =~ /^\[INFO\] --- maven-dependency-plugin:([^ ]+):tree .+/) {
        $line_index = $i + 1;
        last;
    }
}

my $project_group;
my $project_name;
my $project_version;

if ($maven_dependency_tree[$line_index] =~ /^\[INFO\] ([^:]+):([^:]+):[^:]+:([^:]+)$/) {
    ($project_group, $project_name, $project_version) = ($1, $2, $3);
}

$line_index++;

my @dependencies = ();

for (my $i = $line_index; $i < @maven_dependency_tree; $i++) {
    if ($maven_dependency_tree[$i] =~ /^\[INFO\] -+/) {
        last;
    }

    if ($maven_dependency_tree[$i] =~ /^\[INFO\] [+\\]- ([^:]+):([^:]+):[^:]+:([^:]+):([^:]+)/) {
        my ($group, $name, $version, $scope) = ($1, $2, $3, $4);
        push(@dependencies, "\"$group\" % \"$name\" % \"$version\" % \"$scope\"");
    }
}

open my $fh, '>', $sbt_build_file or die "Can't open file:$!";

my $library_dependencies_flat = join(',', @dependencies);

print $fh <<BUILD_FILE;
name := "$project_name"

organization := "$project_group"

scalaVersion := "$scala_version"

updateOptions := updateOptions.value.withCachedResolution(true)

scalacOptions ++= Seq("-Xlint", "-unchecked", "-deprecation", "-feature")

libraryDependencies ++= Seq(
    $library_dependencies_flat
)
BUILD_FILE

close $fh;

system('sbt gen-ensime');

unlink $sbt_build_file;

#!/bin/bash

test_description='Test reffiles backend consistency check'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME
GIT_TEST_DEFAULT_REF_FORMAT=files
export GIT_TEST_DEFAULT_REF_FORMAT

. ./test-lib.sh

test_expect_success 'ref name should be checked' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	(
		cd repo &&
		git commit --allow-empty -m initial &&
		git checkout -b branch-1 &&
		git tag tag-1 &&
		git commit --allow-empty -m second &&
		git checkout -b branch-2 &&
		git tag tag-2
	) &&
	(
		cd repo &&
		cp $branch_dir_prefix/branch-1 $branch_dir_prefix/.branch-1 &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/heads/.branch-1: invalid refname format
		error: ref database is corrupt
		EOF
		rm $branch_dir_prefix/.branch-1 &&
		test_cmp expect err
	) &&
	(
		cd repo &&
		cp $tag_dir_prefix/tag-1 $tag_dir_prefix/tag-1.lock &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/tags/tag-1.lock: invalid refname format
		error: ref database is corrupt
		EOF
		rm $tag_dir_prefix/tag-1.lock &&
		test_cmp expect err
	) &&
	(
		cd repo &&
		cp $branch_dir_prefix/branch-1 $branch_dir_prefix/@ &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/heads/@: invalid refname format
		error: ref database is corrupt
		EOF
		rm $branch_dir_prefix/@ &&
		test_cmp expect err
	)
'

test_expect_success 'ref content should be checked' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	(
		cd repo &&
		git commit --allow-empty -m initial &&
		git checkout -b branch-1 &&
		git tag tag-1 &&
		git commit --allow-empty -m second &&
		git checkout -b branch-2 &&
		git tag tag-2
	) &&
	(
		cd repo &&
		printf "%s garbage" "$(git rev-parse branch-1)" > $branch_dir_prefix/branch-1-garbage &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/heads/branch-1-garbage: invalid ref content
		error: ref database is corrupt
		EOF
		rm $branch_dir_prefix/branch-1-garbage &&
		test_cmp expect err
	) &&
	(
		cd repo &&
		printf "%s garbage" "$(git rev-parse tag-1)" > $tag_dir_prefix/tag-1-garbage &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/tags/tag-1-garbage: invalid ref content
		error: ref database is corrupt
		EOF
		rm $tag_dir_prefix/tag-1-garbage &&
		test_cmp expect err
	) &&
	(
		cd repo &&
		printf "%s    " "$(git rev-parse tag-2)" > $tag_dir_prefix/tag-2-garbage &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/tags/tag-2-garbage: invalid ref content
		error: ref database is corrupt
		EOF
		rm $tag_dir_prefix/tag-2-garbage &&
		test_cmp expect err
	) &&
	(
		cd repo &&
		tr -d "\n" < $branch_dir_prefix/branch-1 > $branch_dir_prefix/branch-1-without-newline &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/heads/branch-1-without-newline: invalid ref content
		error: ref database is corrupt
		EOF
		rm $branch_dir_prefix/branch-1-without-newline &&
		test_cmp expect err
	) &&
	(
		cd repo &&
		tr "[:lower:]" "[:upper:]" < $branch_dir_prefix/branch-2 > $branch_dir_prefix/branch-2-upper &&
		test_must_fail git fsck 2>err &&
		cat >expect <<-EOF &&
		error: refs/heads/branch-2-upper: invalid ref content
		error: ref database is corrupt
		EOF
		rm $branch_dir_prefix/branch-2-upper &&
		test_cmp expect err
	)
'

test_done

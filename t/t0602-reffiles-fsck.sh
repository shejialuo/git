#!/bin/sh

test_description='Test reffiles backend consistency check'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME
GIT_TEST_DEFAULT_REF_FORMAT=files
export GIT_TEST_DEFAULT_REF_FORMAT
TEST_PASSES_SANITIZE_LEAK=true

. ./test-lib.sh

test_expect_success 'ref name should be checked' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	cd repo &&

	git commit --allow-empty -m initial &&
	git checkout -b branch-1 &&
	git tag tag-1 &&
	git commit --allow-empty -m second &&
	git checkout -b branch-2 &&
	git tag tag-2 &&
	git tag multi_hierarchy/tag-2 &&

	cp $branch_dir_prefix/branch-1 $branch_dir_prefix/.branch-1 &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/heads/.branch-1: badRefName: invalid refname format
	EOF
	rm $branch_dir_prefix/.branch-1 &&
	test_cmp expect err &&

	cp $branch_dir_prefix/branch-1 $branch_dir_prefix/@ &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/heads/@: badRefName: invalid refname format
	EOF
	rm $branch_dir_prefix/@ &&
	test_cmp expect err &&

	cp $tag_dir_prefix/multi_hierarchy/tag-2 $tag_dir_prefix/multi_hierarchy/@ &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/multi_hierarchy/@: badRefName: invalid refname format
	EOF
	rm $tag_dir_prefix/multi_hierarchy/@ &&
	test_cmp expect err &&

	cp $tag_dir_prefix/tag-1 $tag_dir_prefix/tag-1.lock &&
	git refs verify 2>err &&
	rm $tag_dir_prefix/tag-1.lock &&
	test_must_be_empty err &&

	cp $tag_dir_prefix/tag-1 $tag_dir_prefix/.lock &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/.lock: badRefName: invalid refname format
	EOF
	rm $tag_dir_prefix/.lock &&
	test_cmp expect err
'

test_expect_success 'ref name check should be adapted into fsck messages' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	cd repo &&
	git commit --allow-empty -m initial &&
	git checkout -b branch-1 &&
	git tag tag-1 &&
	git commit --allow-empty -m second &&
	git checkout -b branch-2 &&
	git tag tag-2 &&

	cp $branch_dir_prefix/branch-1 $branch_dir_prefix/.branch-1 &&
	git -c fsck.badRefName=warn refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/.branch-1: badRefName: invalid refname format
	EOF
	rm $branch_dir_prefix/.branch-1 &&
	test_cmp expect err &&

	cp $branch_dir_prefix/branch-1 $branch_dir_prefix/@ &&
	git -c fsck.badRefName=ignore refs verify 2>err &&
	test_must_be_empty err
'

test_expect_success 'ref name check should work for multiple worktrees' '
	test_when_finished "rm -rf repo" &&
	git init repo &&

	cd repo &&
	test_commit initial &&
	git checkout -b branch-1 &&
	test_commit second &&
	git checkout -b branch-2 &&
	test_commit third &&
	git checkout -b branch-3 &&
	git worktree add ./worktree-1 branch-1 &&
	git worktree add ./worktree-2 branch-2 &&
	worktree1_refdir_prefix=.git/worktrees/worktree-1/refs/worktree &&
	worktree2_refdir_prefix=.git/worktrees/worktree-2/refs/worktree &&

	(
		cd worktree-1 &&
		git update-ref refs/worktree/branch-4 refs/heads/branch-3
	) &&
	(
		cd worktree-2 &&
		git update-ref refs/worktree/branch-4 refs/heads/branch-3
	) &&

	cp $worktree1_refdir_prefix/branch-4 $worktree1_refdir_prefix/.branch-2 &&
	cp $worktree2_refdir_prefix/branch-4 $worktree2_refdir_prefix/@ &&

	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/worktree/.branch-2: badRefName: invalid refname format
	error: refs/worktree/@: badRefName: invalid refname format
	EOF
	sort err >sorted_err &&
	test_cmp expect sorted_err &&

	(
		cd worktree-1 &&
		test_must_fail git refs verify 2>err &&
		cat >expect <<-EOF &&
		error: refs/worktree/.branch-2: badRefName: invalid refname format
		error: refs/worktree/@: badRefName: invalid refname format
		EOF
		sort err >sorted_err &&
		test_cmp expect sorted_err
	) &&

	(
		cd worktree-2 &&
		test_must_fail git refs verify 2>err &&
		cat >expect <<-EOF &&
		error: refs/worktree/.branch-2: badRefName: invalid refname format
		error: refs/worktree/@: badRefName: invalid refname format
		EOF
		sort err >sorted_err &&
		test_cmp expect sorted_err
	)
'

test_expect_success 'regular ref content should be checked (individual)' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	cd repo &&
	test_commit default &&
	mkdir -p "$branch_dir_prefix/a/b" &&

	git refs verify 2>err &&
	test_must_be_empty err &&

	bad_content=$(git rev-parse main)x &&
	printf "%s" $bad_content >$tag_dir_prefix/tag-bad-1 &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/tag-bad-1: badRefContent: $bad_content
	EOF
	rm $tag_dir_prefix/tag-bad-1 &&
	test_cmp expect err &&

	bad_content=xfsazqfxcadas &&
	printf "%s" $bad_content >$tag_dir_prefix/tag-bad-2 &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/tag-bad-2: badRefContent: $bad_content
	EOF
	rm $tag_dir_prefix/tag-bad-2 &&
	test_cmp expect err &&

	bad_content=Xfsazqfxcadas &&
	printf "%s" $bad_content >$branch_dir_prefix/a/b/branch-bad &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/heads/a/b/branch-bad: badRefContent: $bad_content
	EOF
	rm $branch_dir_prefix/a/b/branch-bad &&
	test_cmp expect err
'

test_expect_success 'regular ref content should be checked (aggregate)' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	cd repo &&
	test_commit default &&
	mkdir -p "$branch_dir_prefix/a/b" &&

	bad_content_1=$(git rev-parse main)x &&
	bad_content_2=xfsazqfxcadas &&
	bad_content_3=Xfsazqfxcadas &&
	printf "%s" $bad_content_1 >$tag_dir_prefix/tag-bad-1 &&
	printf "%s" $bad_content_2 >$tag_dir_prefix/tag-bad-2 &&
	printf "%s" $bad_content_3 >$branch_dir_prefix/a/b/branch-bad &&

	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/heads/a/b/branch-bad: badRefContent: $bad_content_3
	error: refs/tags/tag-bad-1: badRefContent: $bad_content_1
	error: refs/tags/tag-bad-2: badRefContent: $bad_content_2
	EOF
	sort err >sorted_err &&
	test_cmp expect sorted_err
'

test_done

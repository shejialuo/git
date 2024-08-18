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

test_expect_success 'regular ref content should be checked' '
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
	git checkout -b a/b/tag-2 &&

	printf "%s" "$(git rev-parse branch-1)" > $branch_dir_prefix/branch-1-no-newline &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/branch-1-no-newline: refMissingNewline: missing newline
	EOF
	rm $branch_dir_prefix/branch-1-no-newline &&
	test_cmp expect err &&

	printf "%s garbage" "$(git rev-parse branch-1)" > $branch_dir_prefix/branch-1-garbage &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/branch-1-garbage: trailingRefContent: trailing garbage in ref
	EOF
	rm $branch_dir_prefix/branch-1-garbage &&
	test_cmp expect err &&

	printf "%s\n\n\n" "$(git rev-parse tag-1)" > $tag_dir_prefix/tag-1-garbage &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/tags/tag-1-garbage: trailingRefContent: trailing garbage in ref
	EOF
	rm $tag_dir_prefix/tag-1-garbage &&
	test_cmp expect err &&

	printf "%s\n\n\n  garbage" "$(git rev-parse tag-1)" > $tag_dir_prefix/tag-1-garbage &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/tags/tag-1-garbage: trailingRefContent: trailing garbage in ref
	EOF
	rm $tag_dir_prefix/tag-1-garbage &&
	test_cmp expect err &&

	printf "%s    garbage\n\na" "$(git rev-parse tag-2)" > $tag_dir_prefix/tag-2-garbage &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/tags/tag-2-garbage: trailingRefContent: trailing garbage in ref
	EOF
	rm $tag_dir_prefix/tag-2-garbage &&
	test_cmp expect err &&

	printf "%s garbage" "$(git rev-parse tag-1)" > $tag_dir_prefix/tag-1-garbage &&
	test_must_fail git -c fsck.trailingRefContent=error refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/tag-1-garbage: trailingRefContent: trailing garbage in ref
	EOF
	rm $tag_dir_prefix/tag-1-garbage &&
	test_cmp expect err &&

	printf "%sx" "$(git rev-parse tag-1)" > $tag_dir_prefix/tag-1-bad &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/tag-1-bad: badRefContent: invalid ref content
	EOF
	rm $tag_dir_prefix/tag-1-bad &&
	test_cmp expect err &&

	printf "xfsazqfxcadas" > $tag_dir_prefix/tag-2-bad &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/tags/tag-2-bad: badRefContent: invalid ref content
	EOF
	rm $tag_dir_prefix/tag-2-bad &&
	test_cmp expect err &&

	printf "xfsazqfxcadas" > $branch_dir_prefix/a/b/branch-2-bad &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/heads/a/b/branch-2-bad: badRefContent: invalid ref content
	EOF
	rm $branch_dir_prefix/a/b/branch-2-bad &&
	test_cmp expect err
'

test_expect_success 'symbolic ref content should be checked' '
	test_when_finished "rm -rf repo" &&
	git init repo &&
	branch_dir_prefix=.git/refs/heads &&
	tag_dir_prefix=.git/refs/tags &&
	cd repo &&
	git commit --allow-empty -m initial &&
	git checkout -b branch-1 &&
	git tag tag-1 &&
	git checkout -b a/b/branch-2 &&

	printf "ref: refs/heads/branch" > $branch_dir_prefix/branch-1-no-newline &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/branch-1-no-newline: refMissingNewline: missing newline
	EOF
	rm $branch_dir_prefix/branch-1-no-newline &&
	test_cmp expect err &&

	printf "ref: refs/heads/branch     " > $branch_dir_prefix/a/b/branch-trailing &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/a/b/branch-trailing: refMissingNewline: missing newline
	warning: refs/heads/a/b/branch-trailing: trailingRefContent: trailing null-garbage
	EOF
	rm $branch_dir_prefix/a/b/branch-trailing &&
	test_cmp expect err &&

	printf "ref: refs/heads/branch\n\n" > $branch_dir_prefix/a/b/branch-trailing &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/a/b/branch-trailing: trailingRefContent: trailing null-garbage
	EOF
	rm $branch_dir_prefix/a/b/branch-trailing &&
	test_cmp expect err &&

	printf "ref: refs/heads/branch \n\n " > $branch_dir_prefix/a/b/branch-trailing &&
	git refs verify 2>err &&
	cat >expect <<-EOF &&
	warning: refs/heads/a/b/branch-trailing: refMissingNewline: missing newline
	warning: refs/heads/a/b/branch-trailing: trailingRefContent: trailing null-garbage
	EOF
	rm $branch_dir_prefix/a/b/branch-trailing &&
	test_cmp expect err &&

	printf "ref: refs/heads/.branch\n" > $branch_dir_prefix/branch-2-bad &&
	test_must_fail git refs verify 2>err &&
	cat >expect <<-EOF &&
	error: refs/heads/branch-2-bad: badSymrefPointee: points to refname with invalid format
	EOF
	rm $branch_dir_prefix/branch-2-bad &&
	test_cmp expect err
'

test_done

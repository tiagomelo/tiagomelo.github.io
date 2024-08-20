---
layout: post
title:  "Jekyll: how to skip code block evaluation"
date:   2024-04-17 13:26:01 -0300
categories: quicktip jekyll liquid
image: "/assets/images/2024-04-17-jekyll-skip-codeblock-evaluation/jekyll-logo.jpg"
---

![jekyll](/assets/images/2024-04-17-jekyll-skip-codeblock-evaluation/jekyll-logo.jpg)

[Jekyll](https://jekyllrb.com/) is a nice tool that enables you write a static website by writing plain text files. This website used it to generate content from [Markdown](https://en.wikipedia.org/wiki/Markdown) files.

Very often I use code blocks to display some code. Example from [https://tiagomelo.info/go/templating/yaml/2023/05/22/golang-templating-replacing-values-yaml-file-coming-from-melo.html](https://tiagomelo.info/go/templating/yaml/2023/05/22/golang-templating-replacing-values-yaml-file-coming-from-melo.html):

![without raw tag](/assets/images/2024-04-17-jekyll-skip-codeblock-evaluation/withoutRawTag.png)

If you try to run Jekyll locally (`bundle exec jekyll serve`), you'll see a bunch of warnings:

{% raw %}
```
Liquid Warning: Liquid syntax error (line 13): [:dot, "."] is not a valid expression in "{{ .AppName }}" in 2024-04-17-jekyll-skip-block-evaluation.markdown
Liquid Warning: Liquid syntax error (line 15): [:dot, "."] is not a valid expression in "{{ .ReplicaCount }}" in 2024-04-17-jekyll-skip-block-evaluation.markdown
Liquid Warning: Liquid syntax error (line 19): [:dot, "."] is not a valid expression in "{{ .AppName }}" in 2024-04-17-jekyll-skip-block-evaluation.markdown
Liquid Warning: Liquid syntax error (line 20): [:dot, "."] is not a valid expression in "{{ .Image }}" in 2024-04-17-jekyll-skip-block-evaluation.markdown

```
{% endraw %}

Even worse, if you're using [GitHub Pages](https://pages.github.com/), this will break the build and thus your website won't be deployed.

That's because [Jekyll](https://jekyllrb.com/) first processes files with [Liquid](https://github.com/Shopify/liquid) and then converts Markdown to HTML, so any [Liquid](https://github.com/Shopify/liquid) inside a Markdown code-block is first Liquid-evaluated and then Markdown-converted.

## Skipping code block evaluation

To avoid evaluating code block content you need to use [raw](https://shopify.github.io/liquid/tags/template/) tag.

Changing our sample code block to use it in a `.markdown` file:

![raw tag](/assets/images/2024-04-17-jekyll-skip-codeblock-evaluation/rawtag.png)

The whole code block won't be interpreted.
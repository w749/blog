---
title: Vuepress操作说明
author: 汪寻
date: 2019-01-01
tags:
 - Other
categories:
 - Other
---

::: tip
Vuepress 基本使用以及 Make down 语法
:::

<!-- more -->

### Vuepress安装

```shell
# 安装nodejs指定版本
yum remove nodejs npm -y
curl -sL https://rpm.nodesource.com/setup_8.x | bash -
yum -y install nodejs

# 安装yarn
curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
yum install -y yarn

node -v
yarn -v

# 安装vuepress-theme-reco
yarn global add @vuepress-reco/theme-cli
theme-cli init blog

# 安装所需插件
cd blog
yarn install
yarn dev

# 中文图片路径支持
yarn add markdown-it-disable-url-encode
# 中文文章名转为拼音
yarn add vuepress-plugin-permalink-pinyin
# 代码复制
yarn add vuepress-plugin-code-copy

```

修改`.vuepress/config.js`文件

```js
// 中文图片路径支持
module.exports = {
  markdown: {
    extendMarkdown: md => {
      md.use(require("markdown-it-disable-url-encode"));
    }
  }
};

// 中文文章名转为拼音
module.exports = {
  plugins: [
      [
        "permalink-pinyin",
        {
          "lowercase": true, // Converted into lowercase, default: true
          "separator": "-", // Separator of the slug, default: '-'
        },
      ],
  ]
}

// 代码复制
module.exports = {
    plugins: [
        ['vuepress-plugin-code-copy', true]
    ]
}
```

### 标题

```md
---
title: 文章标题
author: 汪寻
date: 2021-09-15
tags:
 - Other
categories:
 - Other
---
```

### 摘要

```markdown
::: tip
这是摘要：Vuepress Make down语法
:::

<!-- more -->
```

这是正文

### 容器

::: tip
这是一个提示
:::

::: warning
这是一个警告
:::

::: danger
这是一个危险警告
:::

::: details
这是一个详情块，在 IE / Edge 中不生效
:::

::: danger STOP
危险区域，禁止通行
:::

::: details 点击查看代码
```js
console.log('你好，VuePress！')
```
:::

### 表格

| Tables        |      Are      |  Cool |
| ------------- | :-----------: | ----: |
| col 3 is      | right-aligned | $1600 |
| col 2 is      |   centered    |   $12 |
| zebra stripes |   are neat    |    $1 |

### 图片居中

<div align=center><img src="resources/Spark-Dependencies、Linage and Stage/血缘关系.png"></div>

### 代码高亮

``` js {4}
export default {
  data () {
    return {
      msg: 'Highlighted!'
    }
  }
}
```


class ArticleTagsController < ApplicationController
  def index
    @article_tags = ArticleTag.order(:name)
  end

  def show
    @article_tag = ArticleTag.find_by!(name: params.expect(:name))
    @articles = @article_tag.articles.newest_first
  end
end

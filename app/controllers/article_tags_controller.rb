class ArticleTagsController < ApplicationController
  def index
    @article_tags = ArticleTag.all
  end

  def show
    @article_tag = ArticleTag.find_by(name: params[:name])
    @articles = @article_tag.articles
  end
end

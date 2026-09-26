class ArticlesController < ApplicationController
  def index
    @articles = Article.newest_first
  end

  def show
    @article = Article.find_by!(filename: params.expect(:filename))
  end
end

class ArticlesController < ApplicationController
  def index
    @articles = Article.all
  end

  def show
    @article = Article.find_by(filename: params[:filename])
    @content = File.read(Rails.root.join("content/articles/#{@article.filename}.md"))
  end
end

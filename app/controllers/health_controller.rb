class HealthController < ApplicationController
  skip_forgery_protection

  # Liveness: is the process up at all?
  def show
    render json: { status: "ok", revision: ENV["GIT_SHA"] }, status: :ok
  end

  # Readiness: can we actually serve traffic?
  def ready
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ready" }, status: :ok
  rescue StandardError => e
    render json: { status: "unready", error: e.class.name }, status: :service_unavailable
  end
end

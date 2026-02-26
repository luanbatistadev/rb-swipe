.PHONY: deploy deploy-ios deploy-android build-ios build-android

deploy_all: deploy-ios deploy-android
	@echo "Deploy completo para iOS e Android!"

deploy-ios:
	@echo "Instalando pods..."
	cd ios && pod install
	@echo "Limpando frameworks de simulador..."
	@find ios/Pods -name "*_sim.framework" -type d -exec rm -rf {} + 2>/dev/null || true
	@find ios/Pods -name "*Simulator*.framework" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Subindo para TestFlight..."
	cd ios && bundle exec fastlane beta

deploy-android:
	@echo "Subindo para Firebase App Distribution..."
	cd android && bundle exec fastlane distribute

build-ios:
	@echo "Instalando pods..."
	cd ios && pod install
	@echo "Buildando iOS..."
	cd ios && bundle exec fastlane build

build-android:
	@echo "Buildando Android..."
	cd android && bundle exec fastlane build

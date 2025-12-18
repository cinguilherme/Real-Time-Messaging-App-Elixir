defmodule Messaging.Config.LoaderTest do
  use ExUnit.Case, async: true

  alias Messaging.Config.Loader

  describe "config_path/0" do
    test "returns default path when env var not set" do
      # Clear any existing env var
      System.delete_env("FEATURES_CONFIG")
      Application.delete_env(:messaging_core, :features_config_path)

      # Should use default
      assert Loader.config_path() == "config/features.yaml"
    end

    test "returns configured path from application env" do
      Application.put_env(:messaging_core, :features_config_path, "custom/path.yaml")

      assert Loader.config_path() == "custom/path.yaml"

      # Cleanup
      Application.delete_env(:messaging_core, :features_config_path)
    end
  end

  describe "load!/0" do
    test "raises clear error when config file is missing" do
      # Point to non-existent file
      Application.put_env(:messaging_core, :features_config_path, "nonexistent.yaml")

      assert_raise RuntimeError, ~r/Feature configuration file not found/, fn ->
        Loader.load!()
      end

      # Cleanup
      Application.delete_env(:messaging_core, :features_config_path)
    end

    test "loads and parses valid config file" do
      # Use the test config file
      Application.put_env(:messaging_core, :features_config_path, "config/features.test.yaml")

      config = Loader.load!()

      assert %Messaging.Config{} = config
      assert config.features.receipts == true
      assert config.storage.messages == :postgres
      assert config.jobs.deliver_realtime >= 0

      # Cleanup
      Application.delete_env(:messaging_core, :features_config_path)
    end

    test "raises error on invalid YAML syntax" do
      # Create a temporary invalid YAML file
      invalid_yaml = """
      features:
        receipts: true
        invalid syntax here
      """

      tmp_path = "/tmp/invalid_config_test.yaml"
      File.write!(tmp_path, invalid_yaml)
      Application.put_env(:messaging_core, :features_config_path, tmp_path)

      assert_raise RuntimeError, ~r/Failed to parse YAML/, fn ->
        Loader.load!()
      end

      # Cleanup
      File.rm!(tmp_path)
      Application.delete_env(:messaging_core, :features_config_path)
    end
  end

  describe "reload!/0" do
    test "reloads configuration from disk" do
      Application.put_env(:messaging_core, :features_config_path, "config/features.test.yaml")

      # Load once
      config1 = Loader.load!()

      # Reload
      config2 = Loader.reload!()

      # Should get same values
      assert config1.features.receipts == config2.features.receipts
      assert config1.storage.messages == config2.storage.messages

      # Cleanup
      Application.delete_env(:messaging_core, :features_config_path)
    end
  end
end

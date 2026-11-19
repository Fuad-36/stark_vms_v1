package com.stark_vms_v1.backend.dto;

import com.stark_vms_v1.backend.entity.VehicleType;
import com.stark_vms_v1.backend.validation.MaxCurrentYear;
import com.stark_vms_v1.backend.validation.NormalizedVehicleNumber;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public class VehicleRequest {

    @NotBlank(message = "Vehicle number is required")
    @NormalizedVehicleNumber(max = 20, message = "Vehicle number must not exceed 20 characters")
    private String vehicleNumber;

    @NotNull(message = "Vehicle type is required")
    private VehicleType type;

    @NotBlank(message = "Brand is required")
    @Size(max = 50, message = "Brand must not exceed 50 characters")
    private String brand;

    @NotBlank(message = "Model is required")
    @Size(max = 50, message = "Model must not exceed 50 characters")
    private String model;

    @NotNull(message = "Year is required")
    @Min(value = 1886, message = "Year must be at least 1886")
    @MaxCurrentYear
    private Integer year;

    public VehicleRequest() {
    }

    public VehicleRequest(String vehicleNumber, VehicleType type, String brand, String model, Integer year) {
        this.vehicleNumber = vehicleNumber;
        this.type = type;
        this.brand = brand;
        this.model = model;
        this.year = year;
    }

    public String getVehicleNumber() {
        return vehicleNumber;
    }

    public void setVehicleNumber(String vehicleNumber) {
        this.vehicleNumber = vehicleNumber;
    }

    public VehicleType getType() {
        return type;
    }

    public void setType(VehicleType type) {
        this.type = type;
    }

    public String getBrand() {
        return brand;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public String getModel() {
        return model;
    }

    public void setModel(String model) {
        this.model = model;
    }

    public Integer getYear() {
        return year;
    }

    public void setYear(Integer year) {
        this.year = year;
    }
}

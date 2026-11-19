package com.stark_vms_v1.backend.exception;

public class DuplicateVehicleException extends RuntimeException {

    private final String vehicleNumber;

    public DuplicateVehicleException(String vehicleNumber) {
        super("Vehicle number " + vehicleNumber + " already exists");
        this.vehicleNumber = vehicleNumber;
    }

    public DuplicateVehicleException(String vehicleNumber, String message) {
        super(message);
        this.vehicleNumber = vehicleNumber;
    }

    public String getVehicleNumber() {
        return vehicleNumber;
    }
}

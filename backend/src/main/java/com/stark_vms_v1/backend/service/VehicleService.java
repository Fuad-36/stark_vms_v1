package com.stark_vms_v1.backend.service;

import com.stark_vms_v1.backend.dto.VehicleRequest;
import com.stark_vms_v1.backend.dto.VehicleResponse;
import com.stark_vms_v1.backend.entity.Vehicle;
import com.stark_vms_v1.backend.exception.DuplicateVehicleException;
import com.stark_vms_v1.backend.exception.ResourceNotFoundException;
import com.stark_vms_v1.backend.repository.VehicleRepository;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;

@Service
@Transactional
public class VehicleService {

    private final VehicleRepository vehicleRepository;

    public VehicleService(VehicleRepository vehicleRepository) {
        this.vehicleRepository = vehicleRepository;
    }

    @Transactional(readOnly = true)
    public List<VehicleResponse> getAllVehicles() {
        Sort sort = Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id"));
        return vehicleRepository.findAll(sort)
                .stream()
                .map(VehicleResponse::fromEntity)
                .toList();
    }

    @Transactional(readOnly = true)
    public VehicleResponse getVehicleById(Long id) {
        Vehicle vehicle = vehicleRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found with id: " + id));
        return VehicleResponse.fromEntity(vehicle);
    }

    public VehicleResponse createVehicle(VehicleRequest request) {
        String normalizedNumber = normalizeVehicleNumber(request.getVehicleNumber());
        validateNormalizedVehicleNumber(normalizedNumber);

        if (vehicleRepository.existsByVehicleNumber(normalizedNumber)) {
            throw new DuplicateVehicleException(normalizedNumber, "Vehicle number " + normalizedNumber + " already exists");
        }

        Vehicle vehicle = new Vehicle();
        vehicle.setVehicleNumber(normalizedNumber);
        vehicle.setType(request.getType());
        vehicle.setBrand(request.getBrand());
        vehicle.setModel(request.getModel());
        vehicle.setYear(request.getYear());

        try {
            Vehicle saved = vehicleRepository.saveAndFlush(vehicle);
            return VehicleResponse.fromEntity(saved);
        } catch (DataIntegrityViolationException ex) {
            if (isVehicleNumberConstraintViolation(ex)) {
                throw new DuplicateVehicleException(normalizedNumber, "Vehicle number " + normalizedNumber + " already exists");
            }
            throw ex;
        }
    }

    public VehicleResponse updateVehicle(Long id, VehicleRequest request) {
        Vehicle existing = vehicleRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found with id: " + id));

        String normalizedNumber = normalizeVehicleNumber(request.getVehicleNumber());
        validateNormalizedVehicleNumber(normalizedNumber);

        if (vehicleRepository.existsByVehicleNumberAndIdNot(normalizedNumber, id)) {
            throw new DuplicateVehicleException(normalizedNumber, "Vehicle number " + normalizedNumber + " already exists");
        }

        existing.setVehicleNumber(normalizedNumber);
        existing.setType(request.getType());
        existing.setBrand(request.getBrand());
        existing.setModel(request.getModel());
        existing.setYear(request.getYear());

        try {
            Vehicle updated = vehicleRepository.saveAndFlush(existing);
            return VehicleResponse.fromEntity(updated);
        } catch (DataIntegrityViolationException ex) {
            if (isVehicleNumberConstraintViolation(ex)) {
                throw new DuplicateVehicleException(normalizedNumber, "Vehicle number " + normalizedNumber + " already exists");
            }
            throw ex;
        }
    }

    public void deleteVehicle(Long id) {
        Vehicle vehicle = vehicleRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle not found with id: " + id));
        vehicleRepository.delete(vehicle);
    }

    public static String normalizeVehicleNumber(String vehicleNumber) {
        if (vehicleNumber == null) {
            return null;
        }
        return vehicleNumber.trim().toUpperCase(Locale.ROOT);
    }

    private void validateNormalizedVehicleNumber(String normalizedNumber) {
        if (normalizedNumber == null || normalizedNumber.isBlank()) {
            throw new IllegalArgumentException("Vehicle number is required");
        }
        if (normalizedNumber.length() > 20) {
            throw new IllegalArgumentException("Vehicle number must not exceed 20 characters");
        }
    }

    private boolean isVehicleNumberConstraintViolation(DataIntegrityViolationException ex) {
        java.util.Set<Throwable> visited = java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<>());
        Throwable current = ex;
        while (current != null && visited.add(current)) {
            if (current instanceof ConstraintViolationException cve) {
                String constraintName = cve.getConstraintName();
                if (constraintName != null && constraintName.toLowerCase(Locale.ROOT).contains("uk_vehicle_number")) {
                    return true;
                }
            }
            String msg = current.getMessage();
            if (msg != null && msg.toLowerCase(Locale.ROOT).contains("uk_vehicle_number")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }
}

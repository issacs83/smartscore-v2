"""
Synthetic test image generator for score images
Generates realistic music score images with various distortions
"""

import numpy as np
import cv2
import os
from pathlib import Path


class ScoreImageGenerator:
    """Generate synthetic score images with distortions"""

    @staticmethod
    def generate_clean_score(width: int = 2000, height: int = 2800) -> np.ndarray:
        """
        Generate clean musical score image

        Args:
            width: Image width
            height: Image height

        Returns:
            numpy array (BGR)
        """
        # White background
        image = np.ones((height, width, 3), dtype=np.uint8) * 255

        # Draw dark border for page detection
        border_width = 20
        cv2.rectangle(image, (border_width, border_width),
                     (width - border_width, height - border_width),
                     (0, 0, 0), border_width)

        # Staff parameters
        staff_line_height = 4
        space_height = 12
        staff_spacing = space_height * 4 + staff_line_height * 5  # 5 lines + 4 spaces
        margin = 100

        # Draw staves
        y_pos = margin
        staff_count = 0
        while y_pos < height - margin and staff_count < 4:
            # Draw 5 lines for each staff
            for i in range(5):
                line_y = y_pos + i * (space_height + staff_line_height)
                cv2.line(image, (margin, line_y), (width - margin, line_y),
                        (0, 0, 0), staff_line_height)

            # Draw barline at start
            cv2.line(image, (margin - 20, y_pos), (margin - 20, y_pos + staff_spacing),
                    (0, 0, 0), 3)

            # Draw measure divisions
            measure_width = (width - 2 * margin) // 4
            for m in range(1, 4):
                bar_x = margin + m * measure_width
                cv2.line(image, (bar_x, y_pos), (bar_x, y_pos + staff_spacing),
                        (0, 0, 0), 2)

            # Add measure numbers
            for m in range(4):
                measure_num = staff_count * 4 + m + 1
                text_x = margin + m * measure_width + measure_width // 2 - 10
                text_y = y_pos - 20
                cv2.putText(image, str(measure_num), (text_x, text_y),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

            # Add note heads (filled circles) at random positions
            for m in range(4):
                base_x = margin + m * measure_width
                # Add 2-3 notes per measure
                for _ in range(np.random.randint(2, 4)):
                    # Ensure bounds are valid
                    min_x = base_x + 20
                    max_x = base_x + measure_width - 20
                    if max_x > min_x:
                        note_x = np.random.randint(min_x, max_x)
                    else:
                        note_x = base_x + measure_width // 2
                    # Random line (y between lines)
                    note_y = y_pos + np.random.randint(0, max(1, staff_spacing))
                    # Draw note head (filled circle)
                    cv2.circle(image, (note_x, note_y), 8, (0, 0, 0), -1)

            y_pos += staff_spacing + margin // 2
            staff_count += 1

        return image

    @staticmethod
    def apply_perspective(image: np.ndarray, strength: float = 0.1) -> np.ndarray:
        """
        Apply perspective distortion

        Args:
            image: Input image
            strength: Distortion strength (0-1)

        Returns:
            Perspective-distorted image
        """
        height, width = image.shape[:2]

        # Random corner displacements
        displacement = int(strength * min(height, width))
        corners = np.float32([
            [displacement, displacement],
            [width - displacement, displacement * 0.5],
            [width - displacement * 0.5, height - displacement],
            [displacement * 0.5, height - displacement * 0.5]
        ])

        dst_corners = np.float32([
            [0, 0],
            [width, 0],
            [width, height],
            [0, height]
        ])

        M = cv2.getPerspectiveTransform(corners, dst_corners)
        result = cv2.warpPerspective(image, M, (width, height),
                                    borderMode=cv2.BORDER_REPLICATE)

        return result

    @staticmethod
    def apply_rotation(image: np.ndarray, angle_degrees: float) -> np.ndarray:
        """
        Apply rotation

        Args:
            image: Input image
            angle_degrees: Rotation angle

        Returns:
            Rotated image
        """
        height, width = image.shape[:2]
        center = (width // 2, height // 2)

        M = cv2.getRotationMatrix2D(center, angle_degrees, 1.0)
        result = cv2.warpAffine(image, M, (width, height),
                               borderMode=cv2.BORDER_REPLICATE)

        return result

    @staticmethod
    def apply_shadow(image: np.ndarray, direction: str = "left",
                    intensity: float = 0.5) -> np.ndarray:
        """
        Apply shadow/uneven lighting

        Args:
            image: Input image
            direction: "left", "right", "top", "bottom"
            intensity: Shadow intensity (0-1)

        Returns:
            Shadowed image
        """
        height, width = image.shape[:2]

        # Create gradient mask
        if direction == "left":
            gradient = np.linspace(1.0, 1.0 - intensity, width)
            mask = np.tile(gradient, (height, 1))
        elif direction == "right":
            gradient = np.linspace(1.0 - intensity, 1.0, width)
            mask = np.tile(gradient, (height, 1))
        elif direction == "top":
            gradient = np.linspace(1.0 - intensity, 1.0, height)
            mask = np.tile(gradient[:, np.newaxis], (1, width))
        else:  # bottom
            gradient = np.linspace(1.0, 1.0 - intensity, height)
            mask = np.tile(gradient[:, np.newaxis], (1, width))

        # Apply mask
        if len(image.shape) == 3:
            mask = np.stack([mask] * 3, axis=2)

        result = np.uint8(image.astype(np.float32) * mask)
        return result

    @staticmethod
    def apply_noise(image: np.ndarray, sigma: float = 10.0) -> np.ndarray:
        """
        Add Gaussian noise

        Args:
            image: Input image
            sigma: Noise standard deviation

        Returns:
            Noisy image
        """
        noise = np.random.normal(0, sigma, image.shape).astype(np.int32)
        result = np.uint8(np.clip(image.astype(np.int32) + noise, 0, 255))
        return result

    @staticmethod
    def apply_blur(image: np.ndarray, kernel_size: int = 5) -> np.ndarray:
        """
        Apply Gaussian blur

        Args:
            image: Input image
            kernel_size: Kernel size

        Returns:
            Blurred image
        """
        # Ensure odd kernel size
        if kernel_size % 2 == 0:
            kernel_size += 1

        result = cv2.GaussianBlur(image, (kernel_size, kernel_size), 0)
        return result

    @staticmethod
    def apply_glare(image: np.ndarray, center: tuple = (0.3, 0.3),
                   radius: float = 0.2, intensity: int = 200) -> np.ndarray:
        """
        Apply glare/bright spot

        Args:
            image: Input image
            center: Center as (x_ratio, y_ratio) in 0-1
            radius: Radius as ratio of image dimension
            intensity: Brightness value to overlay

        Returns:
            Image with glare
        """
        height, width = image.shape[:2]
        center_x = int(center[0] * width)
        center_y = int(center[1] * height)
        radius_px = int(radius * min(width, height))

        result = image.copy()

        # Create circular glare mask
        mask = np.zeros((height, width), dtype=np.float32)
        cv2.circle(mask, (center_x, center_y), radius_px, 1.0, -1)

        # Blur the mask for smooth transition
        mask = cv2.GaussianBlur(mask, (51, 51), 0)

        # Apply glare
        if len(result.shape) == 3:
            glare_overlay = np.zeros_like(result, dtype=np.float32)
            glare_overlay[:] = [intensity, intensity, intensity]
            mask_3d = np.stack([mask] * 3, axis=2)
            result = np.uint8(result.astype(np.float32) * (1 - mask_3d * 0.7) +
                            glare_overlay * mask_3d * 0.7)
        else:
            result = np.uint8(result.astype(np.float32) * (1 - mask * 0.7) +
                            intensity * mask * 0.7)

        return result

    @staticmethod
    def generate_test_set(output_dir: str, count: int = 20) -> dict:
        """
        Generate diverse test set with ground truth

        Args:
            output_dir: Directory to save test images
            count: Number of test images to generate

        Returns:
            Dictionary mapping image filename to metadata
        """
        Path(output_dir).mkdir(parents=True, exist_ok=True)

        metadata = {}

        for i in range(count):
            # Generate clean base
            base = ScoreImageGenerator.generate_clean_score()

            # Apply random distortions
            distortions = []

            if i % 5 == 0:
                # Perspective
                base = ScoreImageGenerator.apply_perspective(base, strength=0.15)
                distortions.append('perspective')

            if i % 4 == 0:
                # Rotation
                angle = np.random.uniform(-5, 5)
                base = ScoreImageGenerator.apply_rotation(base, angle)
                distortions.append(f'rotation_{angle:.1f}deg')

            if i % 3 == 0:
                # Shadow
                direction = np.random.choice(['left', 'right', 'top', 'bottom'])
                base = ScoreImageGenerator.apply_shadow(base, direction=direction,
                                                       intensity=0.4)
                distortions.append(f'shadow_{direction}')

            if i % 2 == 0:
                # Noise
                base = ScoreImageGenerator.apply_noise(base, sigma=15)
                distortions.append('noise')

            if i % 6 == 0:
                # Blur
                base = ScoreImageGenerator.apply_blur(base, kernel_size=3)
                distortions.append('blur')

            if i % 7 == 0:
                # Glare
                base = ScoreImageGenerator.apply_glare(base, center=(0.25, 0.35),
                                                      radius=0.15, intensity=220)
                distortions.append('glare')

            # Save image
            filename = f"test_score_{i:03d}.png"
            filepath = os.path.join(output_dir, filename)
            cv2.imwrite(filepath, base)

            # Store metadata
            metadata[filename] = {
                'index': i,
                'distortions': distortions,
                'shape': base.shape,
            }

        return metadata
